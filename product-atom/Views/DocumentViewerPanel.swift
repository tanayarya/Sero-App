import SwiftUI
import PDFKit
import WebKit

// MARK: - Document Viewer Panel

struct DocumentViewerPanel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var zoomLevel: CGFloat = 1.0
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1
    @State private var pdfViewRef: PDFView? = nil

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            viewerToolbar
            Divider()
            ZStack {
                documentContent
                processingOverlay
            }
        }
        .background(isDark ? Color(red: 0.1, green: 0.1, blue: 0.11) : Color(red: 0.96, green: 0.96, blue: 0.97))
        .onChange(of: appState.jumpToPage) { page in
            if let p = page { currentPage = p; appState.jumpToPage = nil }
        }
        .onChange(of: appState.currentDocument?.id) { _ in
            currentPage = 1
            totalPages = 1
            zoomLevel = 1.0
        }
    }

    // MARK: - Toolbar
    @ViewBuilder
    private var viewerToolbar: some View {
        HStack(spacing: 10) {
            // Sidebar toggle
            Button {
                withAnimation { appState.showSidebar.toggle() }
            } label: {
                Image(systemName: appState.showSidebar ? "sidebar.left" : "sidebar.squares.left")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
            }
            .buttonStyle(.plain)
            .help("Toggle sidebar")

            Text(appState.currentDocument?.name ?? "Document")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.2, green: 0.2, blue: 0.2))
                .lineLimit(1)

            if totalPages > 1 {
                pageNavigator
            }
            Spacer()
            zoomControls
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var pageNavigator: some View {
        HStack(spacing: 4) {
            Button { currentPage = max(1, currentPage - 1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .disabled(currentPage <= 1)

            Text("\(currentPage)/\(totalPages)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))

            Button { currentPage = min(totalPages, currentPage + 1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= totalPages)
        }
    }

    @ViewBuilder
    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button { zoomLevel = max(0.5, zoomLevel - 0.25) } label: {
                Image(systemName: "minus.magnifyingglass").font(.system(size: 12))
            }
            .buttonStyle(.plain)
            Text("\(Int(zoomLevel * 100))%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                .frame(width: 36)
            Button { zoomLevel = min(3.0, zoomLevel + 0.25) } label: {
                Image(systemName: "plus.magnifyingglass").font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Document Content
    @ViewBuilder
    private var documentContent: some View {
        if let doc = appState.currentDocument, let url = doc.url {
            switch doc.fileType {
            case .pdf:
                PDFViewerRepresentable(
                    url: url,
                    zoom: zoomLevel,
                    currentPage: $currentPage,
                    totalPages: $totalPages
                )
            case .txt:
                PlainTextViewer(url: url)
            case .markdown:
                MarkdownViewer(url: url)
            }
        } else {
            emptyState
        }
    }

    // MARK: - Processing Overlay
    @ViewBuilder
    private var processingOverlay: some View {
        switch appState.processingState {
        case .extracting:
            processingBanner("Extracting text…", progress: nil)
        case .embedding(let p):
            processingBanner("Generating embeddings \(Int(p * 100))%…", progress: p)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func processingBanner(_ label: String, progress: Double?) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                    .tint(Color(red: 0.039, green: 0.518, blue: 1))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                if let p = progress {
                    Spacer()
                    ProgressView(value: p)
                        .progressViewStyle(.linear)
                        .frame(width: 80)
                        .tint(Color(red: 0.039, green: 0.518, blue: 1))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(16)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 44))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651).opacity(0.4))
            Text("No document open")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - PDF Viewer

struct PDFViewerRepresentable: NSViewRepresentable {
    let url: URL
    let zoom: CGFloat
    @Binding var currentPage: Int
    @Binding var totalPages: Int

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = false
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear
        loadDocument(into: pdfView, context: context)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Reload doc if URL changed
        if context.coordinator.currentURL != url {
            loadDocument(into: pdfView, context: context)
        }
        pdfView.scaleFactor = zoom
        // Navigate to page if changed externally
        if let doc = pdfView.document {
            let rawIdx = (pdfView.currentPage.flatMap { doc.index(for: $0) } ?? 0) + 1
            if rawIdx != currentPage, let page = doc.page(at: currentPage - 1) {
                pdfView.go(to: page)
            }
        }
    }

    private func loadDocument(into pdfView: PDFView, context: Context) {
        let accessing = url.startAccessingSecurityScopedResource()
        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
            let count = doc.pageCount
            DispatchQueue.main.async {
                self.totalPages = count
                self.currentPage = 1
            }
            context.coordinator.currentURL = url
        }
        if accessing { url.stopAccessingSecurityScopedResource() }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var currentURL: URL? = nil
    }
}

// MARK: - Plain Text Viewer

struct PlainTextViewer: View {
    let url: URL
    @State private var content: String = ""

    var body: some View {
        ScrollView {
            Text(content.isEmpty ? "Loading…" : content)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.primary)
                .textSelection(.enabled)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: url) { await loadContent() }
    }

    private func loadContent() async {
        let accessing = url.startAccessingSecurityScopedResource()
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? "Could not read file."
        if accessing { url.stopAccessingSecurityScopedResource() }
        await MainActor.run { content = text }
    }
}

// MARK: - Markdown Viewer

struct MarkdownViewer: View {
    let url: URL
    @State private var attributed: AttributedString = AttributedString("")

    var body: some View {
        ScrollView {
            Text(attributed)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: url) { await loadContent() }
    }

    private func loadContent() async {
        let accessing = url.startAccessingSecurityScopedResource()
        let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if accessing { url.stopAccessingSecurityScopedResource() }
        let result = (try? AttributedString(markdown: raw)) ?? AttributedString(raw)
        await MainActor.run { attributed = result }
    }
}
