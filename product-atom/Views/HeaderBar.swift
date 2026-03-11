import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct HeaderBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            logoSection
            Spacer()
            centerDocLabel
            Spacer()
            trailingControls
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Logo

    @ViewBuilder
    private var logoSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            Text("DocChat")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
        }
    }

    // MARK: - Center doc label

    @ViewBuilder
    private var centerDocLabel: some View {
        if let doc = appState.currentDocument {
            HStack(spacing: 8) {
                Image(systemName: doc.fileType.icon)
                    .foregroundStyle(Color(doc.fileType.tintColor))
                    .font(.system(size: 13))
                Text(doc.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                processingBadge
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var processingBadge: some View {
        switch appState.processingState {
        case .extracting:
            badgeView("Extracting…", color: Color.warningAmber, showSpinner: true)
        case .embedding(let p):
            badgeView("\(Int(p * 100))%", color: Color.appAccent, showSpinner: true)
        case .ready:
            badgeView("Ready", color: Color.successGreen, showSpinner: false)
        case .failed:
            badgeView("Error", color: Color.errorRed, showSpinner: false)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private func badgeView(_ text: String, color: Color, showSpinner: Bool) -> some View {
        HStack(spacing: 4) {
            if showSpinner { ProgressView().controlSize(.mini).tint(color) }
            else { Circle().fill(color).frame(width: 6, height: 6) }
            Text(text).font(.system(size: 10, weight: .medium)).foregroundStyle(color)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Trailing controls

    @ViewBuilder
    private var trailingControls: some View {
        HStack(spacing: 10) {
            uploadButton
            darkModeToggle
            settingsButton
        }
    }

    @ViewBuilder
    private var uploadButton: some View {
        Button { openFilePicker() } label: {
            Label("Open Document", systemImage: "plus.circle.fill")
                .font(.system(size: 13, weight: .medium))
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.appAccent)
        .controlSize(.small)
    }

    @ViewBuilder
    private var darkModeToggle: some View {
        Button {
            let next: String
            switch appState.colorSchemePref {
            case "light": next = "dark"
            case "dark": next = "system"
            default: next = "light"
            }
            appState.colorSchemePref = next
        } label: {
            Image(systemName: darkModeIcon)
                .font(.system(size: 15))
                .foregroundStyle(Color.textSecondary)
        }
        .buttonStyle(.plain)
        .help("Toggle appearance (\(appState.colorSchemePref))")
    }

    private var darkModeIcon: String {
        switch appState.colorSchemePref {
        case "dark": return "moon.fill"
        case "light": return "sun.max.fill"
        default: return "circle.lefthalf.filled"
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        Button { appState.showSettings.toggle() } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 15))
                .foregroundStyle(Color.textSecondary)
        }
        .buttonStyle(.plain)
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
            let fileType: DocFileType
            switch ext {
            case "pdf": fileType = .pdf
            case "md", "markdown": fileType = .markdown
            default: fileType = .txt
            }
            let sizeStr = fileSizeString(url: url)
            let pageCount = ext == "pdf" ? (PDFPageCount(url: url) ?? 1) : 1
            let doc = ChatDocument(
                name: url.lastPathComponent,
                fileType: fileType,
                pageCount: pageCount,
                fileSize: sizeStr,
                url: url
            )
            DispatchQueue.main.async { appState.loadDocument(doc) }
        }
    }

    private func fileSizeString(url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private func PDFPageCount(url: URL) -> Int? {
        return PDFDocument(url: url)?.pageCount
    }
}
