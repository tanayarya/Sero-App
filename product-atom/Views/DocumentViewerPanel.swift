import SwiftUI
import PDFKit
import WebKit

// MARK: - Document Viewer Panel

struct DocumentViewerPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var zoomLevel: CGFloat = 1.0
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1

    var body: some View {
        VStack(spacing: 0) {
            viewerToolbar
            Divider()
            processingOverlay
        }
        .background(Color.surfaceSecondary)
    }

    @ViewBuilder
    private var viewerToolbar: some View {
        HStack(spacing: 12) {
            Text("Document")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            if totalPages > 1 {
                pageIndicator
            }
            Spacer()
            zoomControls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.surfaceSecondary)
    }

    @ViewBuilder
    private var pageIndicator: some View {
        HStack(spacing: 6) {
            Button { currentPage = max(1, currentPage - 1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(currentPage <= 1)
            Text("Page \(currentPage) of \(totalPages)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.textSecondary)
            Button { currentPage = min(totalPages, currentPage + 1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(currentPage >= totalPages)
        }
    }

    @ViewBuilder
    private var zoomControls: some View {
        HStack(spacing: 6) {
            Button { zoomLevel = max(0.5, zoomLevel - 0.25) } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            Text("\(Int(zoomLevel * 100))%")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 38)
            Button { zoomLevel = min(3.0, zoomLevel + 0.25) } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var processingOverlay: some View {
        ZStack {
            documentContent
            if case .extracting = appState.processingState {
                processingBanner(label: "Extracting text…", progress: nil)
            } else if case .embedding(let p) = appState.processingState {
                processingBanner(label: "Generating embeddings… \(Int(p * 100))%", progress: p)
            }
        }
    }

    @ViewBuilder
    private func processingBanner(label: String, progress: Double?) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.appAccent)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                if let p = progress {
                    Spacer()
                    Text("\(Int(p * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(16)
        }
    }

    @ViewBuilder
    private var documentContent: some View {
        if let doc = appState.currentDocument, let url = doc.url {
            switch doc.fileType {
            case .pdf:
                PDFViewerRepresentable(url: url, zoom: zoomLevel, currentPage: $currentPage, totalPages: $totalPages)
            case .txt:
                PlainTextViewer(url: url)
            case .markdown:
                MarkdownViewer(url: url)
            }
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary.opacity(0.5))
            Text("No document open")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textSecondary)
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
        pdfView.backgroundColor = NSColor(Color.surfaceSecondary)
        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
            DispatchQueue.main.async {
                self.totalPages = doc.pageCount
            }
        }
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        pdfView.scaleFactor = zoom
        if let doc = pdfView.document, currentPage != (pdfView.currentPage.flatMap({ doc.index(for: $0) + 1 }) ?? 1) {
            if let page = doc.page(at: currentPage - 1) {
                pdfView.go(to: page)
            }
        }
    }
}

// MARK: - Plain Text Viewer

struct PlainTextViewer: View {
    let url: URL
    @State private var content: String = ""

    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.textPrimary)
                .textSelection(.enabled)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.surfaceSecondary)
        .task {
            content = (try? String(contentsOf: url, encoding: .utf8)) ?? "Could not read file."
        }
    }
}

// MARK: - Markdown Viewer

struct MarkdownViewer: View {
    let url: URL
    @State private var attributedContent: AttributedString = AttributedString("")

    var body: some View {
        ScrollView {
            Text(attributedContent)
                .font(.system(size: 13))
                .foregroundStyle(Color.textPrimary)
                .textSelection(.enabled)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.surfaceSecondary)
        .task {
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return }
            attributedContent = (try? AttributedString(markdown: raw)) ?? AttributedString(raw)
        }
    }
}
