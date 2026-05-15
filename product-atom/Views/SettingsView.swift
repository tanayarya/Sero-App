import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isTestingConnection = false
    @State private var connectionResult: Bool?
    @State private var urlDraft: String = ""
    @State private var useRemoteServer = false
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            Divider()
            settingsContent
            Divider()
            settingsFooter
        }
        .frame(width: 540, height: 620)
        .background(isDark ? Color(red: 0.145, green: 0.137, blue: 0.137) : Color(red: 0.96, green: 0.96, blue: 0.98))
        .onAppear {
            urlDraft = appState.ollamaURL
            useRemoteServer = !isLocalURL(appState.ollamaURL)
            appState.fetchModels()
        }
    }

    @ViewBuilder
    private var settingsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Settings", systemImage: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDark ? .white : Color.black.opacity(0.82))
                Text("Manage your connection, models, and setup flow.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isDark ? .white.opacity(0.88) : Color.black.opacity(0.76))
                    .frame(width: 28, height: 28)
                    .background(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var settingsContent: some View {
        ScrollView(showsIndicators: true) {
            VStack(spacing: 16) {
                runtimeSection
                modelsSection
                setupSection
                appearanceSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private var runtimeSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    modeButton(title: "Use this Mac", icon: "laptopcomputer", isSelected: !useRemoteServer) {
                        useRemoteServer = false
                        urlDraft = "http://localhost:11434"
                        commitURL()
                        connectionResult = nil
                    }
                    modeButton(title: "Use another server", icon: "network", isSelected: useRemoteServer) {
                        useRemoteServer = true
                        connectionResult = nil
                    }
                }

                if useRemoteServer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Server URL")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            TextField("http://192.168.1.40:11434", text: $urlDraft)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color(red: 0.039, green: 0.518, blue: 1).opacity(0.55), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onSubmit { commitURL() }

                            Button(isTestingConnection ? "Testing…" : "Test") {
                                commitURL()
                                testConnection()
                            }
                            .controlSize(.small)
                            .disabled(isTestingConnection)
                        }

                        HStack(spacing: 6) {
                            connectionIndicator
                            Text("Saved on Enter")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        connectionIndicator
                        Text("Using the local Ollama runtime on this Mac.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Refresh") {
                            urlDraft = "http://localhost:11434"
                            commitURL()
                            appState.fetchModels()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var connectionIndicator: some View {
        if let result = connectionResult {
            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result ? Color.green : Color.red)
        } else {
            Circle()
                .fill(appState.ollamaConnected ? Color.green : Color(red: 0.604, green: 0.627, blue: 0.651))
                .frame(width: 8, height: 8)
        }
    }

    @ViewBuilder
    private var modelsSection: some View {
        settingsCard(title: "AI Models", footer: "Recommended: llama3.2 or qwen2.5-coder models") {
            if settingsChatModels.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(useRemoteServer ? "No chat models found on that server yet." : "No models detected. Make sure Ollama is running.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    settingsPickerRow(title: "Chat Model", selection: $appState.selectedModel)
                }
            }
        }
    }

    @ViewBuilder
    private var setupSection: some View {
        settingsCard(title: "Setup") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Setup Assistant")
                        .font(.system(size: 13, weight: .medium))
                    Text("Open the guided setup flow again at any time.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open") {
                    appState.reopenOnboarding()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        settingsCard(title: "Appearance") {
            HStack(spacing: 10) {
                themeButton(title: "System", systemImage: "circle.lefthalf.filled", value: "system")
                themeButton(title: "Light", systemImage: "sun.max", value: "light")
                themeButton(title: "Dark", systemImage: "moon", value: "dark")
            }
        }
    }

    @ViewBuilder
    private var settingsFooter: some View {
        HStack {
            footerButton(
                title: "Refresh Models",
                isPrimary: false,
                action: { appState.fetchModels() }
            )
            Spacer()
            footerButton(
                title: "Done",
                isPrimary: true,
                action: { commitURL(); dismiss() }
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func commitURL() {
        let trimmed = urlDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        appState.ollamaURL = trimmed
        appState.fetchModels()
    }

    private func testConnection() {
        isTestingConnection = true
        connectionResult = nil
        Task {
            let result = await OllamaService.shared.testConnection(baseURL: appState.ollamaURL)
            await MainActor.run {
                connectionResult = result
                appState.ollamaConnected = result
                isTestingConnection = false
                if result { appState.fetchModels() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { connectionResult = nil }
            }
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            content()
            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func settingsPickerRow(title: String, selection: Binding<String>, includeNone: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isDark ? .white : Color.black.opacity(0.78))
            Spacer(minLength: 12)
            Picker(title, selection: selection) {
                if includeNone {
                    Text("None (keyword search)").tag("")
                }
                ForEach(settingsChatModels) { m in
                    Text(m.name).tag(m.name)
                }
            }
            .labelsHidden()
            .frame(width: 220)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func themeButton(title: String, systemImage: String, value: String) -> some View {
        let isSelected = appState.colorSchemePref == value
        Button {
            appState.colorSchemePref = value
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : (isDark ? Color.white.opacity(0.82) : Color.black.opacity(0.75)))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color(red: 0.039, green: 0.518, blue: 1) : (isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var settingsChatModels: [OllamaModel] {
        appState.availableModels.filter {
            let lower = $0.name.lowercased()
            return !lower.contains("embed") && !lower.contains("nomic") && !lower.contains("mxbai")
        }
    }

    @ViewBuilder
    private func modeButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Circle()
                    .fill(isSelected ? Color(red: 0.039, green: 0.518, blue: 1).opacity(0.18) : Color.white.opacity(isDark ? 0.06 : 0.8))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isSelected ? Color(red: 0.039, green: 0.518, blue: 1) : (isDark ? .white : Color.black.opacity(0.75)))
                    }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDark ? .white : Color.black.opacity(0.82))
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .padding(14)
            .background(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color(red: 0.039, green: 0.518, blue: 1).opacity(0.72) : (isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)), lineWidth: isSelected ? 1.4 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func isLocalURL(_ url: String) -> Bool {
        let lower = url.lowercased()
        return lower.contains("localhost") || lower.contains("127.0.0.1")
    }

    @ViewBuilder
    private func footerButton(title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isPrimary ? .semibold : .medium))
                .foregroundStyle(isPrimary ? .white : (isDark ? .white : Color.black.opacity(0.75)))
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(
                    isPrimary
                    ? Color(red: 0.039, green: 0.518, blue: 1)
                    : (isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
