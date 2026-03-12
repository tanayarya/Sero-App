import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isTestingConnection = false
    @State private var connectionResult: Bool?
    @State private var urlDraft: String = ""
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            Divider()
            settingsContent
            Divider()
            settingsFooter
        }
        .frame(width: 480, height: 460)
        .onAppear {
            urlDraft = appState.ollamaURL
            appState.fetchModels()
        }
    }

    @ViewBuilder
    private var settingsHeader: some View {
        HStack {
            Label("Settings", systemImage: "gearshape.fill")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
    }

    @ViewBuilder
    private var settingsContent: some View {
        Form {
            ollamaSection
            modelsSection
            appearanceSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var ollamaSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ollama URL")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    TextField("localhost:11434", text: $urlDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                        .onSubmit { commitURL() }

                    connectionIndicator

                    Button(isTestingConnection ? "Testing…" : "Test") {
                        commitURL()
                        testConnection()
                    }
                    .controlSize(.small)
                    .disabled(isTestingConnection)
                }
            }
        } footer: {
            Text("Default: http://localhost:11434\nSaved automatically on Enter or Test.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
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
        Section {
            if appState.availableModels.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("No models detected. Make sure Ollama is running.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else {
                Picker("Chat Model", selection: $appState.selectedModel) {
                    ForEach(appState.availableModels) { m in
                        Text(m.name).tag(m.name)
                    }
                }
                Picker("Embedding Model", selection: $appState.embeddingModel) {
                    Text("None (keyword search)").tag("")
                    ForEach(appState.availableModels) { m in
                        Text(m.name).tag(m.name)
                    }
                }
            }
        } header: {
            Text("AI Models")
        } footer: {
            Text("Recommended: llama3.2 for chat · nomic-embed-text for embeddings\nInstall: ollama pull nomic-embed-text")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appState.colorSchemePref) {
                Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                Label("Light", systemImage: "sun.max").tag("light")
                Label("Dark", systemImage: "moon").tag("dark")
            }
            .pickerStyle(.radioGroup)
        }
    }

    @ViewBuilder
    private var settingsFooter: some View {
        HStack {
            Button("Refresh Models") { appState.fetchModels() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Spacer()
            Button("Done") { commitURL(); dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.039, green: 0.518, blue: 1))
        }
        .padding(16)
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
}
