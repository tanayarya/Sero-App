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
                    dropZoneSection
                        .padding(.top, 60)
                    stepsSection
                        .padding(.top, 32)
                    recentDocumentsSection
                        .padding(.top, 32)
                        .padding(.bottom, 60)
                }
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Background gradients (Figma radial)
    @ViewBuilder
    private var backgroundGradients: some View {
        ZStack {
            Color(isDark ? .black : .white).ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.039, green: 0.518, blue: 1).opacity(0.18), .clear],
                center: .init(x: 0.25, y: 0.3),
                startRadius: 0, endRadius: 500
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Color.purple.opacity(0.10), .clear],
                center: .init(x: 0.75, y: 0.7),
                startRadius: 0, endRadius: 400
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Drop Zone (Figma center hero)
    @ViewBuilder
    private var dropZoneSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    isDragOver
                        ? Color(red: 0.039, green: 0.518, blue: 1)
                        : (isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.1)),
                    lineWidth: isDragOver ? 2 : 1
                )

            VStack(spacing: 0) {
                // Upload icon button
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.039, green: 0.518, blue: 1).opacity(0.25),
                                         Color(red: 0.039, green: 0.518, blue: 1).opacity(0.08)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .strokeBorder(Color(red: 0.039, green: 0.518, blue: 1).opacity(0.5), lineWidth: 1)
                        )
                    Image(systemName: "arrow.up.doc.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(red: 0.039, green: 0.518, blue: 1))
                }
                .padding(.bottom, 24)

                Text("Chat with your documents")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isDark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                    .padding(.bottom, 12)

                Text("Start a private AI conversation with any PDF, TXT, or\nMarkdown file")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)

                Button { openFilePicker() } label: {
                    Text("Open Document")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.039, green: 0.518, blue: 1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 32)
            }
            .padding(.vertical, 40)
        }
        .frame(maxWidth: 600, minHeight: 280)
        .padding(.horizontal, 20)
        .scaleEffect(isDragOver ? 1.01 : 1.0)
        .animation(.spring(response: 0.3), value: isDragOver)
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Steps Grid (Figma 3-column cards)
    @ViewBuilder
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                stepCard(icon: "arrow.down.doc", title: "Import", desc: "Securely load your\nfiles locally")
                stepCard(icon: "cpu", title: "Process", desc: "AI analyzes context\ninstantly")
                stepCard(icon: "bubble.left.and.text.bubble.right", title: "Ask", desc: "Get answers and\nsummaries")
            }
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
                .font(.custom("Inter", size: 14).weight(.semibold))
                .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.1, green: 0.1, blue: 0.1))
                .padding(.bottom, 6)
            Text(desc)
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(isDark ? Color.black.opacity(0.6) : Color.black.opacity(0.07), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Recent Documents (Figma list)
    @ViewBuilder
    private var recentDocumentsSection: some View {
        let recents = Array(appState.recentDocuments.prefix(3))
        if !recents.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("RECENT DOCUMENTS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                    .padding(.leading, 14)
                    .padding(.bottom, 12)

                VStack(spacing: 6) {
                    ForEach(recents) { doc in
                        recentDocRow(doc)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func recentDocRow(_ doc: ChatDocument) -> some View {
        Button { appState.loadDocument(doc) } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                        .frame(width: 36, height: 36)
                    Image(systemName: doc.fileType.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(red: 0.039, green: 0.518, blue: 1))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(doc.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(1)
                    Text(relativeDate(doc.dateAdded) + " • " + doc.fileSize)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.4, green: 0.4, blue: 0.4))
                    .padding(6)
                    .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    .clipShape(Circle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.02))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.07), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func relativeDate(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60)) min ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

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
            let size = fileSizeString(url: url)
            let pages = ext == "pdf" ? (PDFDocument(url: url)?.pageCount ?? 1) : 1
            let doc = ChatDocument(name: url.lastPathComponent, fileType: fileType, pageCount: pages, fileSize: size, url: url)
            DispatchQueue.main.async { appState.loadDocument(doc) }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data, let fileURL = URL(dataRepresentation: data, relativeTo: nil) else { return }
            let ext = fileURL.pathExtension.lowercased()
            let fileType: DocFileType = ext == "pdf" ? .pdf : (ext == "md" || ext == "markdown") ? .markdown : .txt
            let size = self.fileSizeString(url: fileURL)
            let pages = ext == "pdf" ? (PDFDocument(url: fileURL)?.pageCount ?? 1) : 1
            DispatchQueue.main.async {
                let doc = ChatDocument(name: fileURL.lastPathComponent, fileType: fileType, pageCount: pages, fileSize: size, url: fileURL)
                self.appState.loadDocument(doc)
            }
        }
        return true
    }

    private func fileSizeString(url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "—" }
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: size)
    }
}

// MARK: - How It Works Modal (Figma-matched)

struct HowItWorksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private let blue = Color(red: 0.039, green: 0.518, blue: 1)
    private let subtleGray = Color(red: 0.604, green: 0.627, blue: 0.651)

    private struct Step {
        let number: Int
        let title: String
        let detail: String
        let command: String?
    }

    private let steps: [Step] = [
        Step(number: 1, title: "Install Ollama",
             detail: "Download and install Ollama from ollama.com. It runs as a private local server — no internet required after setup.",
             command: nil),
        Step(number: 2, title: "Pull Required Models",
             detail: "Open Terminal and pull a chat model and an embedding model for document search.",
             command: "ollama pull llama3.2\nollama pull nomic-embed-text"),
        Step(number: 3, title: "Configure the Server URL",
             detail: "Open Settings and set the Ollama URL. The default is localhost:11434 — leave it unchanged if running locally.",
             command: nil),
        Step(number: 4, title: "Test the Connection",
             detail: "Click the Test button in Settings to verify Ollama is reachable and your models are detected.",
             command: nil),
        Step(number: 5, title: "Open a Document",
             detail: "Click Open Document in the header or drag and drop a PDF, TXT, or Markdown file onto the app.",
             command: nil),
        Step(number: 6, title: "Start Chatting",
             detail: "Once the document shows Ready status, type your question in the chat panel. The AI answers using only the document content.",
             command: nil)
    ]

    var body: some View {
        VStack(spacing: 0) {
            modalHeader
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(steps, id: \.number) { step in
                        stepCard(step)
                    }
                }
                .padding(20)
            }
            Divider()
            modalFooter
        }
        .frame(width: 460, height: 560)
        .background(isDark ? Color(red: 0.055, green: 0.063, blue: 0.071) : Color.white)
    }

    @ViewBuilder
    private var modalHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(blue.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "book.open")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(blue)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("How It Works")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                Text("Setup guide for local AI document chat")
                    .font(.system(size: 11))
                    .foregroundStyle(subtleGray)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func stepCard(_ step: Step) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Step number badge
            ZStack {
                Circle()
                    .fill(blue.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(step.number)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(blue)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(step.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.1, green: 0.1, blue: 0.1))
                Text(step.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(subtleGray)
                    .fixedSize(horizontal: false, vertical: true)
                if let cmd = step.command {
                    Text(cmd)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(isDark ? Color(red: 0.376, green: 0.647, blue: 1) : blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isDark ? Color.white.opacity(0.06) : blue.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .textSelection(.enabled)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.025))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.07), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var modalFooter: some View {
        HStack {
            Text("All processing happens locally — your documents never leave your device.")
                .font(.system(size: 11))
                .foregroundStyle(subtleGray)
            Spacer()
            Button("Got it") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(blue)
        }
        .padding(16)
    }
}
