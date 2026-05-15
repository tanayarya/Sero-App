import SwiftUI
import UniformTypeIdentifiers
import PDFKit

// MARK: - Home View (Figma dark design)

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var isDragOver = false
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            backgroundGradients
            ScrollView {
                VStack(spacing: 0) {
                    dropZoneSection.padding(.top, 28)
                    stepsSection.padding(.top, 24)
                    if !appState.recentDocuments.isEmpty {
                        recentDocumentsSection.padding(.top, 28)
                    }
                }
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 48)
            }
        }
    }

    @ViewBuilder
    private var backgroundGradients: some View {
        ZStack {
            Color(isDark ? .black : .white).ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.039, green: 0.518, blue: 1).opacity(0.18), .clear],
                center: .init(x: 0.25, y: 0.3), startRadius: 0, endRadius: 500
            ).ignoresSafeArea()
            RadialGradient(
                colors: [Color.purple.opacity(0.10), .clear],
                center: .init(x: 0.75, y: 0.7), startRadius: 0, endRadius: 400
            ).ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var dropZoneSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    isDragOver ? Color(red: 0.039, green: 0.518, blue: 1)
                    : (isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.1)),
                    lineWidth: isDragOver ? 2 : 1
                )
            dropZoneContent
        }
        .frame(maxWidth: 600)
        .frame(minHeight: 272)
        .padding(.horizontal, 20)
        .scaleEffect(isDragOver ? 1.01 : 1.0)
        .animation(.spring(response: 0.3), value: isDragOver)
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { handleDrop($0) }
    }

    @ViewBuilder
    private var dropZoneContent: some View {
        VStack(spacing: 0) {
            // Logo — top padding matches bottom padding after button
            logoImage.padding(.bottom, 10)
            Text("Ask your documents")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(isDark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                .padding(.bottom, 8)
            Text("Start a private AI conversation with any PDF, TXT, or Markdown file")
                .font(.system(size: 15))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)
            Button { openFilePicker() } label: {
                Text("Open Document")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Color(red: 0.039, green: 0.518, blue: 1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 42)
        .padding(.bottom, 42)
    }

    // To adjust home icon size on landing page: change the height value below (currently 80)
    // To switch back to logo: change Image("homeicon") to Image("logo")
    // To switch homeicon to PNG: update homeicon.imageset/Contents.json filename to "homeicon.png"
    @ViewBuilder
    private var logoImage: some View {
        Image("homeicon")
            .resizable()
            .scaledToFit()
            .frame(height: 26)
    }

    @ViewBuilder
    private var stepsSection: some View {
        HStack(spacing: 16) {
            stepCard(icon: "arrow.down.doc", title: "Import", desc: "Securely load your\nfiles locally")
            stepCard(icon: "cpu", title: "Process", desc: "AI analyzes context\ninstantly")
            stepCard(icon: "bubble.left.and.text.bubble.right", title: "Ask", desc: "Get answers and\nsummaries")
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func stepCard(icon: String, title: String, desc: String) -> some View {
        VStack(alignment: .center, spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.2, green: 0.2, blue: 0.2))
                .padding(.bottom, 14)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.1, green: 0.1, blue: 0.1))
                .padding(.bottom, 6)
            Text(desc)
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20).padding(.horizontal, 12)
        .background(isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.03))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(isDark ? Color.black.opacity(0.6) : Color.black.opacity(0.07), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Recent Documents Section

    @ViewBuilder
    private var recentDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Documents")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                .padding(.leading, 14)
                .padding(.bottom, 6)

            ForEach(Array(appState.recentDocuments.prefix(3))) { doc in
                recentRow(doc)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func recentRow(_ doc: ChatDocument) -> some View {
        Button {
            appState.switchDocument(doc)
        } label: {
            HStack(spacing: 0) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 36, height: 36)
                    Image(systemName: doc.fileType.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            doc.fileType == .pdf
                            ? Color(red: 0.039, green: 0.518, blue: 1)
                            : Color(red: 0.604, green: 0.627, blue: 0.651)
                        )
                }
                .padding(.trailing, 14)

                // Name + meta
                VStack(alignment: .leading, spacing: 3) {
                    Text(doc.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(1)
                    Text(recentSubtitle(doc))
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)

                // Arrow
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 28, height: 28)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.3, green: 0.3, blue: 0.3))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.07), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func recentSubtitle(_ doc: ChatDocument) -> String {
        let interval = Date().timeIntervalSince(doc.dateAdded)
        let timeStr: String
        if interval < 60 { timeStr = "Just now" }
        else if interval < 3600 { timeStr = "\(Int(interval / 60)) mins ago" }
        else if interval < 86400 { timeStr = "\(Int(interval / 3600))h ago" }
        else if interval < 172800 { timeStr = "Yesterday" }
        else {
            let f = DateFormatter(); f.dateFormat = "MMM d"
            timeStr = f.string(from: doc.dateAdded)
        }
        return "\(timeStr) • \(doc.fileSize)"
    }

    // MARK: - Helpers
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .plainText, UTType(filenameExtension: "md") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async { loadURL(url) }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async { loadURL(url) }
        }
        return true
    }

    private func loadURL(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        let fileType: DocFileType = ext == "pdf" ? .pdf : (ext == "md" || ext == "markdown") ? .markdown : .txt
        let size = fileSizeString(url: url)
        let pages = ext == "pdf" ? (PDFDocument(url: url)?.pageCount ?? 1) : 1
        let doc = ChatDocument(name: url.lastPathComponent, fileType: fileType, pageCount: pages, fileSize: size, url: url)
        appState.openFromPicker(url: url, doc: doc)
    }

    private func fileSizeString(url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "—" }
        let f = ByteCountFormatter(); f.countStyle = .file
        return f.string(fromByteCount: size)
    }
}
