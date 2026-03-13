import SwiftUI

// MARK: - How It Works Modal (Figma-matched: 640x722)

struct HowItWorksView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isTesting = false
    @State private var testResult: Bool?
    private var isDark: Bool { colorScheme == .dark }
    private let blue = Color(red: 0.039, green: 0.518, blue: 1)
    private let gray = Color(red: 0.596, green: 0.596, blue: 0.616)

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            stepsSection
            bottomBar
        }
        .frame(width: 640, height: 722)
        .background(isDark ? Color(red: 0.118, green: 0.118, blue: 0.125).opacity(0.95) : Color(red: 0.97, green: 0.97, blue: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .strokeBorder(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Header
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 7) {
            HStack {
                Spacer()
                closeButton
            }
            Text("Set up DocChat in 2 minutes")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(isDark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("DocChat runs locally using Ollama to process your\ndocuments securely and privately.")
                .font(.system(size: 15))
                .foregroundStyle(gray)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 40)
        .padding(.top, 24)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(gray)
                .frame(width: 28, height: 28)
                .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Steps
    @ViewBuilder
    private var stepsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                step1Install
                step2Service
                step3Model
                step4Ready
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: Step 1
    @ViewBuilder
    private var step1Install: some View {
        stepRow(
            icon: "arrow.down.to.line",
            iconBg: isDark
                ? LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                : LinearGradient(colors: [Color.black.opacity(0.06), Color.black.opacity(0.02)], startPoint: .top, endPoint: .bottom),
            iconBorder: isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.12),
            titleText: "Install Ollama",
            descText: "Install the Ollama runtime to run local AI models on your machine."
        ) {
            HStack(spacing: 12) {
                Button { openOllamaURL() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 11))
                        Text("Download Ollama")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                    .background(blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Text("View installation guide")
                    .font(.system(size: 13))
                    .foregroundStyle(gray)
            }
        }
    }

    // MARK: Step 2
    @ViewBuilder
    private var step2Service: some View {
        let iconBg2 = isDark
            ? LinearGradient(colors: [Color(red: 0.145, green: 0.145, blue: 0.153)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color(red: 0.88, green: 0.88, blue: 0.90)], startPoint: .top, endPoint: .bottom)
        stepRow(
            icon: "terminal",
            iconBg: iconBg2,
            iconBorder: isDark ? Color.black.opacity(0.5) : Color.black.opacity(0.12),
            titleText: "Start Ollama Service",
            descText: "Open your terminal and start the background service."
        ) {
            codeBlock("ollama serve")
        }
    }

    // MARK: Step 3
    @ViewBuilder
    private var step3Model: some View {
        let iconBg3 = isDark
            ? LinearGradient(colors: [Color(red: 0.145, green: 0.145, blue: 0.153)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color(red: 0.88, green: 0.88, blue: 0.90)], startPoint: .top, endPoint: .bottom)
        stepRow(
            icon: "brain",
            iconBg: iconBg3,
            iconBorder: isDark ? Color.black.opacity(0.5) : Color.black.opacity(0.12),
            titleText: "Download Model",
            descText: "Pull a lightweight model optimized for document chat."
        ) {
            VStack(alignment: .leading, spacing: 4) {
                codeBlock("ollama pull llama3")
                Text("Downloads ~4GB recommended model.")
                    .font(.system(size: 12))
                    .foregroundStyle(gray)
            }
        }
    }

    // MARK: Step 4
    @ViewBuilder
    private var step4Ready: some View {
        let greenColor = Color(red: 0.157, green: 0.78, blue: 0.435)
        HStack(alignment: .top, spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(greenColor.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(greenColor, lineWidth: 1))
                    .frame(width: 48, height: 48)
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(greenColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("You're Ready")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(greenColor)
                Text("DocChat will automatically detect Ollama once it's running.")
                    .font(.system(size: 14))
                    .foregroundStyle(gray)
            }
            Spacer()
        }
    }

    // MARK: - Step Row Template
    @ViewBuilder
    private func stepRow<Content: View>(
        icon: String,
        iconBg: LinearGradient,
        iconBorder: Color,
        titleText: String,
        descText: String,
        @ViewBuilder extra: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(iconBg)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(iconBorder, lineWidth: 1))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isDark ? .white : Color(red: 0.2, green: 0.2, blue: 0.2))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                Text(descText)
                    .font(.system(size: 14))
                    .foregroundStyle(gray)
                extra().padding(.top, 4)
            }
            Spacer()
        }
    }

    // MARK: - Code Block
    @ViewBuilder
    private func codeBlock(_ command: String) -> some View {
        HStack {
            Text(command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(isDark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                .textSelection(.enabled)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(gray)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 300)
        .background(isDark ? Color(red: 0.067, green: 0.067, blue: 0.067) : Color(red: 0.88, green: 0.89, blue: 0.91))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(isDark ? Color.black.opacity(0.5) : Color.black.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Bottom Bar
    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 12) {
            Divider().frame(height: 0).opacity(0)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(isDark ? Color.black.opacity(0.3) : Color.black.opacity(0.08))
                .frame(height: 1)
        }
        .background(isDark ? Color.black.opacity(0.1) : Color(red: 0.94, green: 0.94, blue: 0.96))

        HStack(spacing: 12) {
            Spacer()
            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.system(size: 14))
                    .foregroundStyle(gray)
                    .padding(.horizontal, 20)
                    .frame(height: 40)
            }
            .buttonStyle(.plain)

            Button {
                testConnection()
            } label: {
                HStack(spacing: 6) {
                    if isTesting {
                        ProgressView().controlSize(.mini).tint(.white)
                    }
                    Text(testButtonLabel)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .frame(height: 40)
                .background(testButtonColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isTesting)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 18)
    }

    private var testButtonLabel: String {
        if isTesting { return "Testing…" }
        if let r = testResult { return r ? "Connected ✓" : "Failed ✗" }
        return "Test Connection"
    }

    private var testButtonColor: Color {
        if let r = testResult { return r ? Color.green : Color.red }
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
