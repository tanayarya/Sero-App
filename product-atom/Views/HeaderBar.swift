import SwiftUI
import UniformTypeIdentifiers
import PDFKit

// MARK: - Header Bar (Figma: dark #0E1012, logo left, doc center, controls right)

struct HeaderBar: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        HStack(spacing: 0) {
            // Traffic light spacer
            Color.clear.frame(width: 72)

            // Logo (left)
            logoView
                .padding(.leading, 8)

            Spacer()

            // Center: document name + status
            if let doc = appState.currentDocument {
                centerLabel(doc: doc)
            }

            Spacer()

            // Right controls
            trailingControls
                .padding(.trailing, 4)
        }
        .frame(height: 52)
        .padding(.horizontal, 20)
        .background(isDark
            ? Color(red: 0.055, green: 0.063, blue: 0.071)
            : Color(red: 0.97, green: 0.97, blue: 0.98))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.1))
                .frame(height: 1)
        }
    }

    // MARK: - Logo
    // Drop your logo.svg into: product-atom/Assets.xcassets/logo.imageset/
    // If not yet added, shows a gradient text fallback
    @ViewBuilder
    private var logoView: some View {
        if let _ = NSImage(named: "logo") {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(height: 22)
        } else {
            // Fallback: gradient italic text logo
            HStack(spacing: 1) {
                Text("Doc")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.039, green: 0.518, blue: 1), Color.purple],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                Text("Chat")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(isDark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
            }
        }
    }

    // MARK: - Center label
    @ViewBuilder
    private func centerLabel(doc: ChatDocument) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: doc.fileType.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.902, green: 0.906, blue: 0.91))
                Text(doc.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.902, green: 0.906, blue: 0.91))
                    .lineLimit(1)
            }
            processingBadge
        }
    }

    @ViewBuilder
    private var processingBadge: some View {
        switch appState.processingState {
        case .extracting:
            statusRow("Extracting…", color: Color(red: 0.996, green: 0.737, blue: 0.18), spinner: true)
        case .embedding(let p):
            statusRow("\(Int(p * 100))% embedded", color: Color(red: 0.039, green: 0.518, blue: 1), spinner: true)
        case .ready:
            statusRow("Ready", color: Color(red: 0.376, green: 1, blue: 0.657), spinner: false)
        case .failed:
            statusRow("Error", color: Color(red: 1, green: 0.373, blue: 0.341), spinner: false)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private func statusRow(_ label: String, color: Color, spinner: Bool) -> some View {
        HStack(spacing: 4) {
            if spinner {
                ProgressView().controlSize(.mini).tint(color)
            } else {
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
        }
    }

    // MARK: - Trailing Controls
    @ViewBuilder
    private var trailingControls: some View {
        HStack(spacing: 12) {
            // How it works (white pill)
            howItWorksButton

            // Open Document (blue pill)
            openDocButton

            // Settings
            iconButton(systemName: "gearshape") {
                appState.showSettings.toggle()
            }
            .help("Settings")

            // Dark mode toggle
            iconButton(systemName: darkModeIcon) {
                let next: String
                switch appState.colorSchemePref {
                case "light": next = "dark"
                case "dark": next = "system"
                default: next = "light"
                }
                appState.colorSchemePref = next
            }
            .help("Toggle appearance")
        }
    }

    @ViewBuilder
    private var howItWorksButton: some View {
        Button { appState.showHowItWorks = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "book.open")
                    .font(.system(size: 11, weight: .medium))
                Text("How it works")
                    .font(.system(size: 13))
            }
            .foregroundStyle(Color.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.white)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var openDocButton: some View {
        Button { openFilePicker() } label: {
            Text("Open Document")
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color(red: 0.039, green: 0.518, blue: 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.0))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var darkModeIcon: String {
        switch appState.colorSchemePref {
        case "dark": return "moon.fill"
        case "light": return "sun.max.fill"
        default: return "circle.lefthalf.filled"
        }
    }

    // MARK: - File Picker
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .plainText, UTType(filenameExtension: "md") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a PDF, TXT, or Markdown file"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let ext = url.pathExtension.lowercased()
            let fileType: DocFileType = ext == "pdf" ? .pdf
                : (ext == "md" || ext == "markdown") ? .markdown : .txt
            let size = fileSizeStr(url: url)
            let pages = ext == "pdf" ? (PDFDocument(url: url)?.pageCount ?? 1) : 1
            let doc = ChatDocument(name: url.lastPathComponent, fileType: fileType,
                                   pageCount: pages, fileSize: size, url: url)
            DispatchQueue.main.async { appState.loadDocument(doc) }
        }
    }

    private func fileSizeStr(url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "—" }
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: size)
    }
}
