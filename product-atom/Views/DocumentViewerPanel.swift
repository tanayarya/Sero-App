import SwiftUI
import PDFKit

// MARK: - Document Viewer Panel

struct DocumentViewerPanel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var zoomLevel: CGFloat = 1.0
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack(alignment: .bottom) {
            background
            documentContent
            if appState.activeDocumentURL != nil {
                floatingToolbar
            }
            processingBanner
        }
        .onChange(of: appState.jumpToPage) { _, page in
            if let p = page { currentPage = p; appState.jumpToPage = nil }
        }
        .onChange(of: appState.activeDocumentURL) { _, _ in
            currentPage = 1; totalPages = 1; zoomLevel = 1.0
        }
    }

    private var background: some View {
        (isDark ? Color(red: 0.147, green: 0.147, blue: 0.147) : Color(red: 0.92, green: 0.92, blue: 0.93))
            .ignoresSafeArea()
    }

    // MARK: - Content

    @ViewBuilder
    private var documentContent: some View {
        if let url = appState.activeDocumentURL, let doc = appState.currentDocument {
            switch doc.fileType {
            case .pdf:
                PDFViewerRepresentable(
                    url: url,
                    zoom: $zoomLevel,
                    currentPage: $currentPage,
                    totalPages: $totalPages
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .txt:
                PlainTextViewer(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .markdown:
                MarkdownViewer(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            emptyState
        }
    }

    // MARK: - Floating Toolbar

    private var floatingToolbar: some View {
        HStack(spacing: 16) {
            toolbarButton(icon: "minus") { zoomLevel = max(0.25, zoomLevel - 0.25) }
            Text("\(Int(zoomLevel * 100))%")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.white).frame(minWidth: 36)
            toolbarButton(icon: "plus") { zoomLevel = min(4.0, zoomLevel + 0.25) }

            Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: 16)

            toolbarButton(icon: "chevron.up", disabled: currentPage <= 1) {
                currentPage = max(1, currentPage - 1)
            }
            Text(totalPages > 0 ? "\(currentPage) / \(totalPages)" : "—")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.white).frame(minWidth: 44)
            toolbarButton(icon: "chevron.down", disabled: currentPage >= totalPages) {
                currentPage = min(totalPages, currentPage + 1)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(Color(red: 0.118, green: 0.118, blue: 0.118).opacity(0.94))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 4)
        .padding(.bottom, 20)
    }

    private func toolbarButton(icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(disabled
                    ? Color(red: 0.604, green: 0.627, blue: 0.651).opacity(0.3)
                    : Color(red: 0.604, green: 0.627, blue: 0.651))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Processing Banner

    @ViewBuilder
    private var processingBanner: some View {
        switch appState.processingState {
        case .extracting:
            bannerView("Extracting text…", progress: nil)
        case .embedding(let p):
            bannerView("Generating embeddings \(Int(p * 100))%…", progress: p)
        default:
            EmptyView()
        }
    }

    private func bannerView(_ label: String, progress: Double?) -> some View {
        VStack {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small).tint(Color(red: 0.039, green: 0.518, blue: 1))
                Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.primary)
                if let p = progress {
                    Spacer()
                    ProgressView(value: p).progressViewStyle(.linear).frame(width: 80)
                        .tint(Color(red: 0.039, green: 0.518, blue: 1))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.top, 16).padding(.horizontal, 20)
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651).opacity(0.3))
            Text("No document open")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
            Text("Open a document from the sidebar\nor drag and drop a file here")
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651).opacity(0.6))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - PDF Viewer
// CRITICAL: Always load via Data to avoid sandbox path-based access failures.

struct PDFViewerRepresentable: NSViewRepresentable {
    let url: URL
    @Binding var zoom: CGFloat
    @Binding var currentPage: Int
    @Binding var totalPages: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = false
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor(red: 0.147, green: 0.147, blue: 0.147, alpha: 1)
        pdfView.pageShadowsEnabled = true

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageDidChange(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        context.coordinator.pdfView = pdfView
        context.coordinator.onPageChange = { page in
            DispatchQueue.main.async { self.currentPage = page }
        }
        loadDocument(into: pdfView, context: context)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if context.coordinator.loadedPath != url.path {
            loadDocument(into: pdfView, context: context)
        }
        if abs(pdfView.scaleFactor - zoom) > 0.01 {
            pdfView.scaleFactor = zoom
        }
        if let doc = pdfView.document {
            let idx = max(0, min(doc.pageCount - 1, currentPage - 1))
            if let targetPage = doc.page(at: idx) {
                let curIdx = pdfView.currentPage.flatMap { doc.index(for: $0) } ?? 0
                if curIdx != idx { pdfView.go(to: targetPage) }
            }
        }
    }

    private func loadDocument(into pdfView: PDFView, context: Context) {
        context.coordinator.loadedPath = url.path
        NSLog("[DocChat] Loading PDF: %@", url.path)

        // Always load via Data — avoids any secondary sandbox path checks
        DispatchQueue.global(qos: .userInitiated).async {
            var pdfDoc: PDFDocument?

            // Try Data first (works even when only scope-based access is active)
            if let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
                pdfDoc = PDFDocument(data: data)
                NSLog("[DocChat] PDF loaded via Data: %d pages", pdfDoc?.pageCount ?? 0)
            }

            // Fallback: try URL directly
            if pdfDoc == nil {
                pdfDoc = PDFDocument(url: url)
                NSLog("[DocChat] PDF loaded via URL fallback: %d pages", pdfDoc?.pageCount ?? 0)
            }

            DispatchQueue.main.async {
                if let doc = pdfDoc, doc.pageCount > 0 {
                    pdfView.document = doc
                    let count = doc.pageCount
                    self.totalPages = count
                    self.currentPage = 1
                    // Set initial zoom to fit width
                    pdfView.autoScales = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        pdfView.autoScales = false
                        self.zoom = pdfView.scaleFactor
                    }
                    NSLog("[DocChat] PDFView ready with %d pages", count)
                } else {
                    NSLog("[DocChat] Failed to load PDF: %@", url.path)
                }
            }
        }
    }

    class Coordinator: NSObject {
        var loadedPath: String?
        weak var pdfView: PDFView?
        var onPageChange: ((Int) -> Void)?

        @objc func pageDidChange(_ notification: Notification) {
            guard let pv = notification.object as? PDFView,
                  let doc = pv.document,
                  let current = pv.currentPage else { return }
            let idx = doc.index(for: current)
            onPageChange?(idx + 1)
        }
    }
}

// MARK: - Plain Text Viewer

struct PlainTextViewer: View {
    let url: URL
    @State private var content: String = ""
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading…").padding(40)
            } else {
                Text(content)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.primary)
                    .textSelection(.enabled)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task(id: url.absoluteString) {
            isLoading = true
            let text = (try? String(contentsOf: url, encoding: .utf8))
                ?? (try? String(contentsOf: url, encoding: .isoLatin1))
                ?? "Could not read file."
            await MainActor.run {
                content = text
                isLoading = false
            }
        }
    }
}

// MARK: - Markdown Viewer

struct MarkdownViewer: View {
    let url: URL
    @State private var attributed: AttributedString = AttributedString("")
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading…").padding(40)
            } else {
                Text(attributed)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task(id: url.absoluteString) {
            isLoading = true
            let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let parsed = (try? AttributedString(
                markdown: raw,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
            )) ?? AttributedString(raw)
            await MainActor.run {
                attributed = parsed
                isLoading = false
            }
        }
    }
}
