import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                heroSection
                ollamaStatusBanner
                supportedFormatsSection
                recentDocumentsSection
                quickStartSection
            }
            .padding(40)
        }
        .background(Color.surfacePrimary)
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appAccentLight)
                    .frame(width: 88, height: 88)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }
            Text("Chat with your documents")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
            Text("Drop a PDF, TXT, or Markdown file to start a private, local AI conversation about its contents.")
                .font(.system(size: 15))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            dropZone
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.appAccent.opacity(0.6))
            Text("Drag & drop a document here")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: 420, minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundStyle(Color.appAccent.opacity(0.25))
        )
        .background(Color.appAccentLight.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Ollama Status

    @ViewBuilder
    private var ollamaStatusBanner: some View {
        let connected = appState.ollamaConnected
        HStack(spacing: 10) {
            Image(systemName: connected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(connected ? Color.successGreen : Color.warningAmber)
            VStack(alignment: .leading, spacing: 2) {
                let statusText = connected ? "Ollama is running" : "Ollama not detected"
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                let detail = connected
                    ? "Connected to \(appState.ollamaURL)"
                    : "Please start Ollama to use DocChat. Download from ollama.com"
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Button("Test Connection") {
                checkOllamaConnection()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(16)
        .background(Color.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: 560)
    }

    // MARK: - Formats

    @ViewBuilder
    private var supportedFormatsSection: some View {
        VStack(spacing: 12) {
            Text("Supported Formats")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            HStack(spacing: 16) {
                ForEach(DocFileType.allCases, id: \.self) { ft in
                    formatCard(ft)
                }
            }
        }
    }

    @ViewBuilder
    private func formatCard(_ ft: DocFileType) -> some View {
        VStack(spacing: 8) {
            Image(systemName: ft.icon)
                .font(.system(size: 24))
                .foregroundStyle(Color(ft.tintColor))
            Text(ft.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
        }
        .frame(width: 110, height: 80)
        .background(Color.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Docs

    @ViewBuilder
    private var recentDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Documents")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            if appState.documents.isEmpty {
                emptyRecentState
            } else {
                recentDocsList
            }
        }
        .frame(maxWidth: 560, alignment: .leading)
    }

    @ViewBuilder
    private var emptyRecentState: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(Color.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("No documents yet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Text("Open a file to get started")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(Color.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var recentDocsList: some View {
        VStack(spacing: 8) {
            ForEach(appState.documents.suffix(5)) { doc in
                recentDocRow(doc)
            }
        }
    }

    @ViewBuilder
    private func recentDocRow(_ doc: ChatDocument) -> some View {
        Button {
            appState.currentDocument = doc
        } label: {
            HStack(spacing: 12) {
                Image(systemName: doc.fileType.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color(doc.fileType.tintColor))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Text("\(doc.fileType.label) • \(doc.fileSize)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(12)
            .background(Color.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Start

    @ViewBuilder
    private var quickStartSection: some View {
        VStack(spacing: 12) {
            Text("How it Works")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            HStack(spacing: 16) {
                stepCard(number: 1, icon: "arrow.down.doc", title: "Import", desc: "Open a PDF, TXT, or Markdown file")
                stepCard(number: 2, icon: "cpu", title: "Process", desc: "Text is extracted and embedded locally")
                stepCard(number: 3, icon: "bubble.left.and.text.bubble.right", title: "Chat", desc: "Ask questions and get smart answers")
            }
        }
        .frame(maxWidth: 560)
    }

    @ViewBuilder
    private func stepCard(number: Int, icon: String, title: String, desc: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.appAccentLight)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Text(desc)
                .font(.system(size: 11))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(12)
        .background(Color.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url = url else { return }
            let ext = url.pathExtension.lowercased()
            let fileType: DocFileType
            switch ext {
            case "pdf": fileType = .pdf
            case "md", "markdown": fileType = .markdown
            default: fileType = .txt
            }
            DispatchQueue.main.async {
                let doc = ChatDocument(name: url.lastPathComponent, fileType: fileType, url: url)
                appState.addDocument(doc)
            }
        }
        return true
    }

    private func checkOllamaConnection() {
        guard let url = URL(string: appState.ollamaURL) else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                let http = response as? HTTPURLResponse
                appState.ollamaConnected = (http?.statusCode == 200)
            }
        }.resume()
    }
}
