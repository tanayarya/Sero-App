import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isTestingConnection = false
    @State private var connectionResult: Bool? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            settingsContent
            Divider()
            footer
        }
        .frame(width: 460, height: 420)
        .background(Color.surfacePrimary)
        .onAppear { appState.fetchModels() }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack {
            Label("Settings", systemImage: "gearshape.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Content

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
            HStack {
                TextField("http://localhost:11434", text: $appState.ollamaURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .onSubmit { appState.fetchModels() }
                connectionStatusBadge
                Button(isTestingConnection ? "Testing…" : "Test") {
                    testConnection()
                }
                .controlSize(.small)
                .disabled(isTestingConnection)
            }
        } header: {
            Text("Ollama Server URL")
        } footer: {
            Text("Default: http://localhost:11434 — your settings are saved automatically.")
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
        }
    }

    @ViewBuilder
    private var connectionStatusBadge: some View {
        if let result = connectionResult {
            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result ? Color.successGreen : Color.errorRed)
        } else if appState.ollamaConnected {
            Circle().fill(Color.successGreen).frame(width: 8, height: 8)
        } else {
            Circle().fill(Color.errorRed).frame(width: 8, height: 8)
        }
    }

    @ViewBuilder
    private var modelsSection: some View {
        Section {
            if appState.availableModels.isEmpty {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("No models detected. Make sure Ollama is running and has models installed.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
            } else {
                Picker("Chat Model", selection: $appState.selectedModel) {
                    ForEach(appState.availableModels) { m in
                        Text(m.name).tag(m.name)
                    }
                }
                Picker("Embedding Model", selection: $appState.embeddingModel) {
                    ForEach(appState.availableModels) { m in
                        Text(m.name).tag(m.name)
                    }
                }
            }
        } header: {
            Text("AI Models")
        } footer: {
            Text("Models are fetched from your Ollama instance. Install models via: ollama pull nomic-embed-text")
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
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

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        HStack {
            Button("Refresh Models") { appState.fetchModels() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
        }
        .padding(16)
    }

    // MARK: - Connection Test

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
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    connectionResult = nil
                }
            }
        }
    }
}
