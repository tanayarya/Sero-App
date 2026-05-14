import SwiftUI

struct HowItWorksView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isChecking = false
    @State private var isReady = false

    private var isDark: Bool { colorScheme == .dark }
    private let blue = Color(red: 0.039, green: 0.518, blue: 1)

    var body: some View {
        ZStack {
            modalBackground
            VStack(spacing: 0) {
                header
                steps
                footer
            }
            .padding(28)
        }
        .frame(width: 620)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(isDark ? 0.1 : 0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 40, x: 0, y: 24)
    }

    private var modalBackground: some View {
        LinearGradient(
            colors: [
                isDark ? Color(red: 0.13, green: 0.14, blue: 0.16) : Color(red: 0.94, green: 0.95, blue: 0.97),
                isDark ? Color(red: 0.09, green: 0.10, blue: 0.12) : Color(red: 0.9, green: 0.92, blue: 0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("How Sero works")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isDark ? .white : Color(red: 0.08, green: 0.1, blue: 0.14))
                Text("Bring in a document, let Sero understand it, then ask questions in plain language.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                    .frame(maxWidth: 430, alignment: .leading)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isDark ? .white.opacity(0.72) : Color.black.opacity(0.65))
                    .frame(width: 32, height: 32)
                    .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var steps: some View {
        VStack(spacing: 14) {
            glassStep(
                number: "01",
                title: "Open a file",
                detail: "Choose a PDF, TXT, or Markdown file from your Mac and Sero prepares it for chat."
            )
            glassStep(
                number: "02",
                title: "Pick a model",
                detail: "Use the model already on this Mac or download one that fits your device."
            )
            glassStep(
                number: "03",
                title: "Ask naturally",
                detail: "Ask for summaries, specific details, or quick takeaways without leaving the document."
            )
        }
        .padding(.top, 24)
    }

    private func glassStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(blue.opacity(isDark ? 0.18 : 0.12))
                    .frame(width: 40, height: 40)
                Text(number)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(blue)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isDark ? .white : Color(red: 0.08, green: 0.1, blue: 0.14))
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(18)
        .background(isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.84))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(isDark ? 0.08 : 0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            statusPill
            Spacer()
            secondaryButton("Close") {
                dismiss()
            }
            if isReady {
                primaryButton("Dive in") {
                    dismiss()
                }
            } else {
                primaryButton(isChecking ? "Checking" : "Check setup") {
                    checkConnection()
                }
                .disabled(isChecking)
            }
        }
        .padding(.top, 24)
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            if isChecking {
                ProgressView()
                    .controlSize(.mini)
                    .tint(blue)
            } else {
                Circle()
                    .fill(isReady ? Color.successGreen : Color.warningAmber)
                    .frame(width: 8, height: 8)
            }
            Text(isChecking ? "Checking your local setup" : (isReady ? "Sero is ready to chat" : "Check your setup when you are ready"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isDark ? .white.opacity(0.82) : Color.black.opacity(0.72))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.75))
        .clipShape(Capsule())
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(blue)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isDark ? .white : Color.black.opacity(0.75))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.82))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func checkConnection() {
        isChecking = true
        isReady = false
        Task {
            let ok = await OllamaService.shared.testConnection(baseURL: appState.ollamaURL)
            await MainActor.run {
                isReady = ok
                isChecking = false
                if ok {
                    appState.fetchModels()
                }
            }
        }
    }
}
