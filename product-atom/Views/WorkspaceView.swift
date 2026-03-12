import SwiftUI
import UniformTypeIdentifiers
import PDFKit

// MARK: - Workspace View (Figma: Sidebar 260 | Viewer flex | Chat 391)

struct WorkspaceView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar (260px, Figma)
            if appState.showSidebar {
                SidebarView()
                    .frame(width: 260)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            // Divider
            Rectangle()
                .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.1))
                .frame(width: 1)

            // Main document viewer (flex)
            DocumentViewerPanel()
                .frame(minWidth: 400)

            // Right divider
            Rectangle()
                .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.1))
                .frame(width: 1)

            // Right chat panel (391px, Figma)
            ChatPanel()
                .frame(width: 391)
        }
        .animation(.easeInOut(duration: 0.2), value: appState.showSidebar)
        .onDrop(of: [.fileURL], isTargeted: nil) { handleDrop($0) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async { loadURL(url) }
        }
        return true
    }

    private func loadURL(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        let fileType: DocFileType = ext == "pdf" ? .pdf : (ext == "md" || ext == "markdown") ? .markdown : .txt
        let size = fileSizeStr(url: url)
        let pages = ext == "pdf" ? (PDFDocument(url: url)?.pageCount ?? 1) : 1
        let doc = ChatDocument(name: url.lastPathComponent, fileType: fileType, pageCount: pages, fileSize: size, url: url)
        appState.loadDocument(doc)
    }

    private func fileSizeStr(url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "—" }
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: size)
    }
}

// MARK: - Sidebar (Figma: dark background, Active + Recent sections)

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private let blue = Color(red: 0.039, green: 0.518, blue: 1)
    private let subtleGray = Color(red: 0.604, green: 0.627, blue: 0.651)

    var body: some View {
        VStack(spacing: 20) {
            // Active section
            activeSection

            // Recent section
            recentSection

            Spacer()

            // Add Document button (bottom)
            addDocumentButton
        }
        .padding(16)
        .background(isDark ? Color.black : Color(red: 0.96, green: 0.96, blue: 0.97))
    }

    // MARK: - Active Section
    @ViewBuilder
    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row with sidebar collapse button
            HStack {
                Button {
                    withAnimation { appState.showSidebar.toggle() }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12))
                        .foregroundStyle(subtleGray)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Text("Active")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(subtleGray)
                Spacer()
            }

            if let doc = appState.currentDocument {
                // Active document row (blue highlight)
                HStack(spacing: 10) {
                    Image(systemName: doc.fileType.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.376, green: 0.647, blue: 1))
                        .frame(width: 16)
                    Text(doc.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.376, green: 0.647, blue: 1))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(blue.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Recent Section
    @ViewBuilder
    private var recentSection: some View {
        let recents = appState.recentDocuments.filter { $0.id != appState.currentDocument?.id }.prefix(10)
        if !recents.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(subtleGray)
                    .padding(.leading, 8)

                VStack(spacing: 4) {
                    ForEach(Array(recents)) { doc in
                        recentRow(doc)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recentRow(_ doc: ChatDocument) -> some View {
        Button { appState.switchDocument(doc) } label: {
            HStack(spacing: 10) {
                Image(systemName: doc.fileType.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(subtleGray)
                    .frame(width: 16)
                Text(doc.name)
                    .font(.system(size: 13))
                    .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.2, green: 0.2, blue: 0.2))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Document Button (Figma bottom)
    @ViewBuilder
    private var addDocumentButton: some View {
        Button { openFilePicker() } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.902, green: 0.906, blue: 0.91))
                Text("Add Document")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.902, green: 0.906, blue: 0.91))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.1), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
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
            let doc = ChatDocument(name: url.lastPathComponent, fileType: fileType, pageCount: pages, fileSize: size, url: url)
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
