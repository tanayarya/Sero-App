import SwiftUI
import UniformTypeIdentifiers
import PDFKit

// MARK: - Workspace View with Sidebar

struct WorkspaceView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        HStack(spacing: 0) {
            if appState.showSidebar {
                SidebarView()
                    .frame(width: 220)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                Divider()
            }
            DocumentViewerPanel()
                .frame(minWidth: 320)
            Divider()
            ChatPanel()
                .frame(minWidth: 300, maxWidth: 520)
        }
        .animation(.easeInOut(duration: 0.2), value: appState.showSidebar)
        .onDrop(of: [.fileURL], isTargeted: nil) { handleDrop($0) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            let ext = url.pathExtension.lowercased()
            let fileType: DocFileType = ext == "pdf" ? .pdf : (ext == "md" || ext == "markdown") ? .markdown : .txt
            let size = fileSizeStr(url: url)
            let pages = ext == "pdf" ? (PDFDocument(url: url)?.pageCount ?? 1) : 1
            DispatchQueue.main.async {
                let doc = ChatDocument(name: url.lastPathComponent, fileType: fileType, pageCount: pages, fileSize: size, url: url)
                appState.loadDocument(doc)
            }
        }
        return true
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

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider()
            ScrollView {
                VStack(spacing: 2) {
                    let recents = appState.recentDocuments.prefix(10)
                    if recents.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 24))
                                .foregroundStyle(.secondary)
                            Text("No recent documents")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(Array(recents)) { doc in
                            sidebarRow(doc)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
            }
        }
        .background(isDark ? Color(red: 0.12, green: 0.12, blue: 0.13) : Color(red: 0.95, green: 0.95, blue: 0.96))
    }

    @ViewBuilder
    private var sidebarHeader: some View {
        HStack {
            Text("Documents")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func sidebarRow(_ doc: ChatDocument) -> some View {
        let isActive = appState.currentDocument?.id == doc.id
        Button { appState.switchDocument(doc) } label: {
            HStack(spacing: 8) {
                Image(systemName: doc.fileType.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(
                        isActive
                            ? Color(red: 0.039, green: 0.518, blue: 1)
                            : Color(red: 0.604, green: 0.627, blue: 0.651)
                    )
                    .frame(width: 16)
                Text(doc.name)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(
                        isActive
                            ? (isDark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                            : Color(red: 0.604, green: 0.627, blue: 0.651)
                    )
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isActive
                    ? Color(red: 0.039, green: 0.518, blue: 1).opacity(0.15)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}
