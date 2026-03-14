import SwiftUI
import UniformTypeIdentifiers
import PDFKit

// MARK: - Header Bar (Figma: dark #0E1012, logo left, doc center, controls right)

struct HeaderBar: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private let gray = Color(red: 0.604, green: 0.627, blue: 0.651)

    var body: some View {
        ZStack {
            // Center doc label
            if let doc = appState.currentDocument {
                centerLabel(doc: doc)
                    .frame(maxWidth: .infinity)
            }
            // Logo pinned left, controls pinned right
            HStack(spacing: 0) {
                logoView
                Spacer()
                trailingControls.padding(.trailing, 4)
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 20)
        .background(isDark ? Color(red: 0.055, green: 0.063, blue: 0.071) : Color(red: 0.97, green: 0.97, blue: 0.98))
        .overlay(alignment: .bottom) {
            Rectangle().fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.1)).frame(height: 1)
        }
    }

    // MARK: - Logo (uses asset "logo")
    // To adjust logo size in header: change the height value below (currently 32)
    @ViewBuilder
    private var logoView: some View {
        Image("logo")
            .resizable()
            .scaledToFit()
            .frame(height: 32)
    }

    // MARK: - Center label
    @ViewBuilder
    private func centerLabel(doc: ChatDocument) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: doc.fileType.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.2, green: 0.2, blue: 0.2))
                Text(doc.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.1, green: 0.1, blue: 0.1))
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
            Text(label).font(.system(size: 11)).foregroundStyle(gray)
        }
    }

    // MARK: - Trailing Controls
    @ViewBuilder
    private var trailingControls: some View {
        HStack(spacing: 12) {
            howItWorksButton
            openDocButton
            iconButton(systemName: "gearshape") { appState.showSettings.toggle() }
            iconButton(systemName: darkModeIcon) {
                let next: String
                switch appState.colorSchemePref {
                case "light": next = "dark"
                case "dark": next = "system"
                default: next = "light"
                }
                appState.colorSchemePref = next
            }
        }
    }

    @ViewBuilder
    private var howItWorksButton: some View {
        Button { appState.showHowItWorks = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "book.open").font(.system(size: 11, weight: .medium))
                Text("How it works").font(.system(size: 13))
            }
            .foregroundStyle(Color.black)
            .padding(.horizontal, 14).padding(.vertical, 7)
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
                .padding(.horizontal, 14).padding(.vertical, 7)
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
                .foregroundStyle(isDark ? Color.white : Color(red: 0.3, green: 0.3, blue: 0.3))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    private var darkModeIcon: String {
        switch appState.colorSchemePref {
        case "dark": return "moon.fill"
        case "light": return "sun.max.fill"
        default: return "circle.lefthalf.filled"
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .plainText, UTType(filenameExtension: "md") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let ext = url.pathExtension.lowercased()
            let fileType: DocFileType = ext == "pdf" ? .pdf : (ext == "md" || ext == "markdown") ? .markdown : .txt
            let size = fileSizeStr(url: url)
            let pages = ext == "pdf" ? (PDFDocument(url: url)?.pageCount ?? 1) : 1
            // Create doc with bookmark for recents persistence
            let doc = ChatDocument(
                name: url.lastPathComponent,
                fileType: fileType, pageCount: pages,
                fileSize: size, url: url
            )
            DispatchQueue.main.async {
                appState.openFromPicker(url: url, doc: doc)
            }
        }
    }

    private func fileSizeStr(url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "—" }
        let f = ByteCountFormatter(); f.countStyle = .file
        return f.string(fromByteCount: size)
    }
}
