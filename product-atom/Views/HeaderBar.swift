import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct HeaderBar: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        HStack(spacing: 0) {
            // macOS traffic light spacer
            trafficLightArea
            logoSection
            Spacer()
            centerDocLabel
            Spacer()
            trailingControls
        }
        .frame(height: 52)
        .padding(.horizontal, 20)
        .background(
            isDark
                ? Color(red: 0.173, green: 0.173, blue: 0.18).opacity(0.85)
                : Color(red: 0.96, green: 0.96, blue: 0.97).opacity(0.95)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isDark ? Color.black.opacity(0.6) : Color.black.opacity(0.1))
                .frame(height: 1)
        }
    }

    // MARK: - Traffic light placeholder (window buttons drawn by system)
    @ViewBuilder
    private var trafficLightArea: some View {
        Color.clear.frame(width: 72, height: 1)
    }

    // MARK: - Logo
    @ViewBuilder
    private var logoSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 0.039, green: 0.518, blue: 1))
            Text("DocChat")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(isDark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
        }
    }

    // MARK: - Center label
    @ViewBuilder
    private var centerDocLabel: some View {
        if let doc = appState.currentDocument {
            HStack(spacing: 6) {
                Image(systemName: doc.fileType.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.039, green: 0.518, blue: 1))
                Text(doc.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.2, green: 0.2, blue: 0.2))
                    .lineLimit(1)
                processingBadge
            }
        }
    }

    @ViewBuilder
    private var processingBadge: some View {
        switch appState.processingState {
        case .extracting:
            statusCapsule("Extracting…", color: Color(red: 0.996, green: 0.737, blue: 0.18), spinner: true)
        case .embedding(let p):
            statusCapsule("\(Int(p * 100))%", color: Color(red: 0.039, green: 0.518, blue: 1), spinner: true)
        case .ready:
            statusCapsule("Ready", color: Color(red: 0.157, green: 0.784, blue: 0.251), spinner: false)
        case .failed:
            statusCapsule("Error", color: Color(red: 1, green: 0.373, blue: 0.341), spinner: false)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private func statusCapsule(_ label: String, color: Color, spinner: Bool) -> some View {
        HStack(spacing: 4) {
            if spinner { ProgressView().controlSize(.mini).tint(color) }
            else { Circle().fill(color).frame(width: 5, height: 5) }
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(color)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Trailing
    @ViewBuilder
    private var trailingControls: some View {
        HStack(spacing: 8) {
            howItWorksButton
            uploadButton
            darkModeToggle
            settingsButton
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
            .foregroundStyle(isDark ? Color.black : Color.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isDark ? Color.white : Color.white)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var uploadButton: some View {
        Button { openFilePicker() } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .help("Open Document")
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
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .help("Settings")
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
            let fileType: DocFileType = ext == "pdf" ? .pdf : (ext == "md" || ext == "markdown") ? .markdown : .txt
            let size = fileSizeStr(url: url)
            let pages = ext == "pdf" ? (PDFDocument(url: url)?.pageCount ?? 1) : 1
            let doc = ChatDocument(name: url.lastPathComponent, fileType: fileType, pageCount: pages, fileSize: size, url: url)
            DispatchQueue.main.async { appState.loadDocument(doc) }
        }
    }

    private func fileSizeStr(url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "—" }
        let f = ByteCountFormatter(); f.countStyle = .file
        return f.string(fromByteCount: size)
    }
}
