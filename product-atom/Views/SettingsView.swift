import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            settingsForm
            Divider()
            footer
        }
        .frame(width: 440, height: 360)
        .background(Color.surfacePrimary)
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("Settings")
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

    @ViewBuilder
    private var settingsForm: some View {
        Form {
            Section("Ollama Configuration") {
                TextField("Server URL", text: $appState.ollamaURL)
                Picker("Chat Model", selection: $appState.selectedModel) {
                    ForEach(appState.availableModels, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                TextField("Embedding Model", text: $appState.embeddingModel)
            }
            Section("Status") {
                statusRow
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var statusRow: some View {
        HStack {
            let connected = appState.ollamaConnected
            Circle()
                .fill(connected ? Color.successGreen : Color.errorRed)
                .frame(width: 8, height: 8)
            Text(connected ? "Connected" : "Disconnected")
                .font(.system(size: 13))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Button("Test") {
                testConnection()
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
                .controlSize(.regular)
        }
        .padding(16)
    }

    private func testConnection() {
        guard let url = URL(string: appState.ollamaURL) else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                let http = response as? HTTPURLResponse
                appState.ollamaConnected = (http?.statusCode == 200)
            }
        }.resume()
    }
}
