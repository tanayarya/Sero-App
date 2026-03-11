import SwiftUI

// MARK: - Chat Panel

struct ChatPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText: String = ""
    @State private var inputFocused: Bool = false
    @FocusState private var textFieldFocused: Bool
    @State private var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        VStack(spacing: 0) {
            chatToolbar
            Divider()
            messagesArea
            Divider()
            inputBar
        }
        .background(Color.surfaceChat)
        .onAppear { textFieldFocused = true }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var chatToolbar: some View {
        HStack {
            Label("Chat", systemImage: "bubble.left.and.text.bubble.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            processingStatus
            Button { appState.clearChat() } label: {
                Image(systemName: "trash").font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .disabled(appState.messages.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var processingStatus: some View {
        switch appState.processingState {
        case .ready:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.successGreen)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.successGreen.opacity(0.12))
                .clipShape(Capsule())
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.errorRed)
                .lineLimit(1)
        case .extracting, .embedding:
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                Text("Processing…").font(.system(size: 11)).foregroundStyle(Color.textSecondary)
            }
        case .idle:
            EmptyView()
        }
    }

    // MARK: - Messages

    @ViewBuilder
    private var messagesArea: some View {
        if appState.messages.isEmpty {
            emptyChatState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.messages) { msg in
                            MessageBubbleView(message: msg)
                                .id(msg.id)
                        }
                        if appState.isStreaming && appState.messages.last?.role != .assistant {
                            TypingIndicatorView()
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .onChange(of: appState.messages.count) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: appState.messages.last?.content) { _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyChatState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "text.bubble")
                .font(.system(size: 38))
                .foregroundStyle(Color.chatBubbleAI.opacity(0.5))
            Text(appState.currentDocument != nil ? "Ask a question about your document" : "Open a document to start chatting")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            if appState.currentDocument != nil && appState.processingState == .ready {
                VStack(spacing: 6) {
                    suggestChip("Summarize the key points")
                    suggestChip("What are the main topics?")
                    suggestChip("List the conclusions or findings")
                    suggestChip("Explain in simple terms")
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func suggestChip(_ text: String) -> some View {
        Button { inputText = text; textFieldFocused = true } label: {
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.chatBubbleAI)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.chatBubbleAI.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input Bar

    @ViewBuilder
    private var inputBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                MultilineTextField(text: $inputText, isFocused: $textFieldFocused) {
                    sendMessage()
                }
                .frame(minHeight: 36, maxHeight: 120)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button { sendMessage() } label: {
                    Image(systemName: appState.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(canSend ? Color.chatBubbleAI : Color.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)

            Text("Shift+Return for new line  •  / to focus")
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
                .padding(.bottom, 8)
        }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !appState.isStreaming
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !appState.isStreaming else { return }
        inputText = ""
        appState.sendMessage(trimmed)
        textFieldFocused = true
    }
}

// MARK: - Multiline TextField

struct MultilineTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let tv = scrollView.documentView as? NSTextView else { return scrollView }
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.font = .systemFont(ofSize: 13)
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.textContainerInset = .init(width: 0, height: 2)
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        context.coordinator.textView = tv
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? NSTextView else { return }
        if tv.string != text { tv.string = text }
        if isFocused { tv.window?.makeFirstResponder(tv) }
        tv.textColor = NSColor(Color.textPrimary)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MultilineTextField
        weak var textView: NSTextView?

        init(_ parent: MultilineTextField) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Enter sends, Shift+Enter inserts newline
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let shiftDown = NSEvent.modifierFlags.contains(.shift)
                if shiftDown {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                } else {
                    parent.onSubmit()
                    return true
                }
            }
            return false
        }
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) var colorScheme

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isUser { Spacer(minLength: 44) }
            if !isUser { aiAvatar }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                bubbleBody
                if let page = message.sourcePage, !isUser {
                    pageCitation(page)
                }
            }
            if !isUser { Spacer(minLength: 44) }
        }
    }

    @ViewBuilder
    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.chatBubbleAI.opacity(0.15))
                .frame(width: 26, height: 26)
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.chatBubbleAI)
        }
        .alignmentGuide(.bottom) { d in d[.bottom] }
    }

    @ViewBuilder
    private var bubbleBody: some View {
        if isUser {
            Text(message.content)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(Color.chatBubbleUser)
                .clipShape(BubbleShape(isUser: true))
        } else {
            FormattedResponseView(text: message.content, isStreaming: message.isStreaming)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(Color.chatBubbleAIBg)
                .clipShape(BubbleShape(isUser: false))
        }
    }

    @ViewBuilder
    private func pageCitation(_ page: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "doc.text").font(.system(size: 9))
            Text("Page \(page)").font(.system(size: 10))
        }
        .foregroundStyle(Color.textTertiary)
        .padding(.leading, 34)
    }
}

// MARK: - Formatted Response View (Markdown-aware)

struct FormattedResponseView: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let attributed = try? AttributedString(markdown: text) {
                Text(attributed)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isStreaming && !text.isEmpty {
                streamingCursor
            }
        }
    }

    @ViewBuilder
    private var streamingCursor: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.chatBubbleAI)
            .frame(width: 6, height: 14)
            .opacity(0.8)
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.chatBubbleAI.opacity(0.15))
                    .frame(width: 26, height: 26)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.chatBubbleAI)
            }
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.chatBubbleAI.opacity(phase == i ? 1.0 : 0.3))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color.chatBubbleAIBg)
            .clipShape(BubbleShape(isUser: false))
            Spacer()
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isUser: Bool
    let radius: CGFloat = 16
    let tail: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let (minX, maxX, minY, maxY) = (rect.minX, rect.maxX, rect.minY, rect.maxY)
        if isUser {
            p.move(to: CGPoint(x: minX + radius, y: minY))
            p.addLine(to: CGPoint(x: maxX - radius, y: minY))
            p.addQuadCurve(to: CGPoint(x: maxX, y: minY + radius), control: CGPoint(x: maxX, y: minY))
            p.addLine(to: CGPoint(x: maxX, y: maxY - tail - radius))
            p.addQuadCurve(to: CGPoint(x: maxX - radius, y: maxY - tail), control: CGPoint(x: maxX, y: maxY - tail))
            p.addLine(to: CGPoint(x: minX + radius, y: maxY))
            p.addQuadCurve(to: CGPoint(x: minX, y: maxY - radius), control: CGPoint(x: minX, y: maxY))
            p.addLine(to: CGPoint(x: minX, y: minY + radius))
            p.addQuadCurve(to: CGPoint(x: minX + radius, y: minY), control: CGPoint(x: minX, y: minY))
        } else {
            p.move(to: CGPoint(x: minX + radius, y: minY))
            p.addLine(to: CGPoint(x: maxX - radius, y: minY))
            p.addQuadCurve(to: CGPoint(x: maxX, y: minY + radius), control: CGPoint(x: maxX, y: minY))
            p.addLine(to: CGPoint(x: maxX, y: maxY - radius))
            p.addQuadCurve(to: CGPoint(x: maxX - radius, y: maxY), control: CGPoint(x: maxX, y: maxY))
            p.addLine(to: CGPoint(x: minX + radius, y: maxY))
            p.addQuadCurve(to: CGPoint(x: minX, y: maxY - radius), control: CGPoint(x: minX, y: maxY))
            p.addLine(to: CGPoint(x: minX, y: minY + tail + radius))
            p.addQuadCurve(to: CGPoint(x: minX + radius, y: minY), control: CGPoint(x: minX, y: minY))
        }
        p.closeSubpath()
        return p
    }
}
