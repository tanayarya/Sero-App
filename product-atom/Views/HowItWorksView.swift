import SwiftUI

// MARK: - How It Works Modal

struct HowItWorksView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isTesting = false
    @State private var testResult: Bool?

    private var isDark: Bool { colorScheme == .dark }
    private let blue = Color(red: 0.039, green: 0.518, blue: 1)
    private let subtext = Color(red: 0.55, green: 0.55, blue: 0.57)
    private let surfaceBg: Color = Color(red: 0.118, green: 0.118, blue: 0.128)
    private let cardBg: Color = Color(red: 0.16, green: 0.16, blue: 0.175)
    private let border: Color = Color.white.opacity(0.07)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.15)
            steps
            Divider().opacity(0.15)
            footer
        }
        .frame(width: 560)
        .background(surfaceBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 40, x: 0, y: 20)
    }

    // MARK: Header
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Set up Sero")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Runs locally via Ollama — private and offline.")
                    .font(.system(size: 13))
                    .foregroundStyle(subtext)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(subtext)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
    }

    // MARK: Steps
    private var steps: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepRow(number: "1", icon: "arrow.down.to.line",
                    title: "Install Ollama",
                    desc: "Install the Ollama runtime to run AI models locally.") {
                HStack(spacing: 10) {
                    Button { openOllamaURL() } label: {
                        Label("Download Ollama", systemImage: "arrow.down.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 30)
                            .background(blue)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Text("ollama.com")
                        .font(.system(size: 12))
                        .foregroundStyle(blue.opacity(0.8))
                }
            }

            stepDivider

            stepRow(number: "2", icon: "terminal",
                    title: "Start Ollama Service",
                    desc: "Open Terminal and run the background service.") {
                codeBlock("ollama serve")
            }

            stepDivider

            stepRow(number: "3", icon: "brain",
                    title: "Download a Model",
                    desc: "Pull a lightweight model optimised for document chat.") {
                VStack(alignment: .leading, spacing: 6) {
                    codeBlock("ollama pull llama3")
                    Text("~4 GB download · stored locally")
                        .font(.system(size: 11))
                        .foregroundStyle(subtext)
                }
            }

            stepDivider

            // Step 4 — ready
            let green = Color(red: 0.157, green: 0.78, blue: 0.435)
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(green.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("You're ready")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(green)
                    Text("Sero auto-detects Ollama once it's running.")
                        .font(.system(size: 12))
                        .foregroundStyle(subtext)
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
        }
    }

    private var stepDivider: some View {
        Divider()
            .opacity(0.10)
            .padding(.horizontal, 28)
    }

    @ViewBuilder
    private func stepRow<Extra: View>(
        number: String,
        icon: String,
        title: String,
        desc: String,
        @ViewBuilder extra: () -> Extra
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(subtext)
                extra().padding(.top, 6)
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }

    // MARK: Code Block
    @ViewBuilder
    private func codeBlock(_ command: String) -> some View {
        HStack(spacing: 8) {
            Text(command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.85))
                .textSelection(.enabled)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(subtext)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: Footer
    private var footer: some View {
        HStack(spacing: 12) {
            Spacer()
            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.system(size: 13))
                    .foregroundStyle(subtext)
                    .padding(.horizontal, 18)
                    .frame(height: 36)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            Button { testConnection() } label: {
                HStack(spacing: 6) {
                    if isTesting {
                        ProgressView().controlSize(.mini).tint(.white)
                    }
                    Text(testButtonLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 18)
                .frame(height: 36)
                .background(testButtonColor)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isTesting)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    // MARK: Helpers
    private var testButtonLabel: String {
        if isTesting { return "Testing…" }
        if let r = testResult { return r ? "Connected ✓" : "Retry" }
        return "Test Connection"
    }

    private var testButtonColor: Color {
        if let r = testResult { return r ? Color(red: 0.157, green: 0.78, blue: 0.435) : Color.red.opacity(0.8) }
        return blue
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            let ok = await OllamaService.shared.testConnection(baseURL: appState.ollamaURL)
            await MainActor.run {
                testResult = ok
                isTesting = false
                if ok { appState.fetchModels() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { testResult = nil }
            }
        }
    }

    private func openOllamaURL() {
        if let url = URL(string: "https://ollama.com") {
            NSWorkspace.shared.open(url)
        }
    }
}
