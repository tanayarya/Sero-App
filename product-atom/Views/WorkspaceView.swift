import SwiftUI
import UniformTypeIdentifiers
import PDFKit

// MARK: - Helpers

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - Workspace View (Figma: Sidebar 260 | Viewer flex | Chat resizable)

struct WorkspaceView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var chatWidth: CGFloat = 391
    @State private var isDragging = false
    private let chatMinWidth: CGFloat = 280
    private let chatMaxWidth: CGFloat = 600
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                if appState.showSidebar {
                    SidebarView()
                        .frame(width: 260)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    sidebarExpandStrip
                }

                dividerLine

                DocumentViewerPanel()
                    .frame(minWidth: 300)

                resizableDivider(geo: geo)

                ChatPanel()
                    .frame(width: chatWidth)
            }
            .animation(.easeInOut(duration: 0.2), value: appState.showSidebar)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { handleDrop($0) }
    }

    @ViewBuilder
    private var dividerLine: some View {
        Rectangle()
            .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.1))
            .frame(width: 1)
    }

    @ViewBuilder
    private func resizableDivider(geo: GeometryProxy) -> some View {
        ZStack {
            Rectangle()
                .fill(isDragging
                      ? Color(red: 0.039, green: 0.518, blue: 1).opacity(0.6)
                      : (isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.1)))
                .frame(width: isDragging ? 2 : 1)
        }
        .frame(width: 8)
        .contentShape(Rectangle())
        .cursor(.resizeLeftRight)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    isDragging = true
                    let delta = -value.translation.width
                    let newWidth = (chatWidth + delta).clamped(to: chatMinWidth...chatMaxWidth)
                    chatWidth = newWidth
                }
                .onEnded { _ in isDragging = false }
        )
    }

    // Collapsed sidebar: thin strip with expand button
    @ViewBuilder
    private var sidebarExpandStrip: some View {
        VStack {
            Button {
                withAnimation { appState.showSidebar = true }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                    .frame(width: 28, height: 28)
                    .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            Spacer()
        }
        .frame(width: 44)
        .background(isDark ? Color.black : Color(red: 0.96, green: 0.96, blue: 0.97))
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
        appState.openFromPicker(url: url, doc: doc)
    }

    private func fileSizeStr(url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "—" }
        let f = ByteCountFormatter(); f.countStyle = .file
        return f.string(fromByteCount: size)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private let blue = Color(red: 0.039, green: 0.518, blue: 1)
    private let gray = Color(red: 0.604, green: 0.627, blue: 0.651)

    var body: some View {
        VStack(spacing: 20) {
            activeSection
            recentSection
            Spacer()
            addDocumentButton
        }
        .padding(16)
        .background(isDark ? Color.black : Color(red: 0.96, green: 0.96, blue: 0.97))
    }

    @ViewBuilder
    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { withAnimation { appState.showSidebar.toggle() } } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12))
                        .foregroundStyle(gray)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                Text("Active")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(gray)
                Spacer()
            }
            if let doc = appState.currentDocument {
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
                .padding(.horizontal, 8).padding(.vertical, 8)
                .background(blue.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        let recents = appState.recentDocuments.filter { $0.id != appState.currentDocument?.id }.prefix(10)
        if !recents.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(gray)
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
                    .foregroundStyle(gray)
                    .frame(width: 16)
                Text(doc.name)
                    .font(.system(size: 13))
                    .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.2, green: 0.2, blue: 0.2))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 8)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var addDocumentButton: some View {
        Button { openFilePicker() } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                Text("Add Document")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.2, green: 0.2, blue: 0.2))
            .padding(.horizontal, 10).padding(.vertical, 10)
            .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.1), lineWidth: 1))
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
            DispatchQueue.main.async { appState.openFromPicker(url: url, doc: doc) }
        }
    }

    private func fileSizeStr(url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "—" }
        let f = ByteCountFormatter(); f.countStyle = .file
        return f.string(fromByteCount: size)
    }
}
