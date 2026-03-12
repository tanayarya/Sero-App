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
    private let blue = Color(red: 0.039, green: 0.518, blue: 1)

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                documentContent
            }
            .background(isDark ? Color(red: 0.147, green: 0.147, blue: 0.147) : Color(red: 0.92, green: 0.92, blue: 0.93))

            floatingToolbar

            processingOverlay
        }
        .onChange(of: appState.jumpToPage) { page in
            if let p = page {
                currentPage = p
                appState.jumpToPage = nil
            }
        }
        .onChange(of: appState.currentDocument?.id) { _ in
            currentPage = 1
            totalPages = 1
            zoomLevel = 1.0
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
                    zoom: $zoomLevel,
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

    // MARK: - Floating Toolbar (Figma design)
    @ViewBuilder
    private var floatingToolbar: some View {
        if appState.currentDocument != nil {
            HStack(spacing: 16) {
                // Zoom Out
                Button { zoomLevel = max(0.5, zoomLevel - 0.25) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)

                Text("\(Int(zoomLevel * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(minWidth: 36)

                // Zoom In
                Button { zoomLevel = min(3.0, zoomLevel + 0.25) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 16)

                // Prev page
                Button { currentPage = max(1, currentPage - 1) } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .disabled(currentPage <= 1)

                Text(totalPages > 0 ? "\(currentPage) / \(totalPages)" : "—")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(minWidth: 40)

                // Next page
                Button { currentPage = min(totalPages, currentPage + 1) } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .disabled(currentPage >= totalPages)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(red: 0.118, green: 0.118, blue: 0.118).opacity(0.9))
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 4)
            .padding(.bottom, 20)
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
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color(red: 0.039, green: 0.518, blue: 1))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                if let p = progress {
                    Spacer()
                    ProgressView(value: p)
                        .progressViewStyle(.linear)
                        .frame(width: 80)
                        .tint(Color(red: 0.039, green: 0.518, blue: 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: - Empty State
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651).opacity(0.3))
            Text("No document open")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - PDF Viewer (fixed: keep security scope open for PDFView lifetime)

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
        loadPDF(into: pdfView, context: context)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Reload if URL changed
        if context.coordinator.currentURL?.absoluteString != url.absoluteString {
            // Stop old security scope
            if let old = context.coordinator.currentURL {
                old.stopAccessingSecurityScopedResource()
            }
            loadPDF(into: pdfView, context: context)
        }

        // Apply zoom
        let targetScale = zoom
        if abs(pdfView.scaleFactor - targetScale) > 0.01 {
            pdfView.scaleFactor = targetScale
        }

        // Navigate to page
        if let doc = pdfView.document {
            let pageIndex = currentPage - 1
            let clampedIndex = max(0, min(doc.pageCount - 1, pageIndex))
            if let targetPage = doc.page(at: clampedIndex) {
                let curIdx = pdfView.currentPage.flatMap { doc.index(for: $0) } ?? 0
                if curIdx != clampedIndex {
                    pdfView.go(to: targetPage)
                }
            }
        }
    }

    private func loadPDF(into pdfView: PDFView, context: Context) {
        // Start security scope and KEEP IT OPEN while PDF is displayed
        let accessing = url.startAccessingSecurityScopedResource()
        context.coordinator.securityScopeActive = accessing
        context.coordinator.currentURL = url

        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
            let count = doc.pageCount
            DispatchQueue.main.async {
                self.totalPages = count
                self.currentPage = 1
            }
        }
    }

    static func dismantleNSView(_ pdfView: PDFView, coordinator: Coordinator) {
        // Release security scope when view is removed
        if coordinator.securityScopeActive, let url = coordinator.currentURL {
            url.stopAccessingSecurityScopedResource()
            coordinator.securityScopeActive = false
        }
    }

    class Coordinator: NSObject {
        var currentURL: URL?
        var securityScopeActive = false
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
                ProgressView("Loading…")
                    .padding(40)
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
            await loadContent()
            isLoading = false
        }
    }

    private func loadContent() async {
        let accessing = url.startAccessingSecurityScopedResource()
        let text = (try? String(contentsOf: url, encoding: .utf8))
            ?? (try? String(contentsOf: url, encoding: .isoLatin1))
            ?? "Could not read file."
        if accessing { url.stopAccessingSecurityScopedResource() }
        await MainActor.run { content = text }
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
                ProgressView("Loading…")
                    .padding(40)
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
            await loadContent()
            isLoading = false
        }
    }

    private func loadContent() async {
        let accessing = url.startAccessingSecurityScopedResource()
        let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if accessing { url.stopAccessingSecurityScopedResource() }
        let result = (try? AttributedString(markdown: raw,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)))
            ?? AttributedString(raw)
        await MainActor.run { attributed = result }
    }
}
