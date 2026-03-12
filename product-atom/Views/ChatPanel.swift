import SwiftUI
import AppKit

// MARK: - Chat Panel

struct ChatPanel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            chatToolbar
            Divider()
            messagesArea
            Divider()
            inputBar
        }
        .background(isDark ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(red: 0.97, green: 0.97, blue: 0.98))
        .onReceive(NotificationCenter.default.publisher(for: .focusChatInput)) { _ in
            isInputFocused = true
        }
    }

    // MARK: - Toolbar
    @ViewBuilder
    private var chatToolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
            Text("Chat")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.2, green: 0.2, blue: 0.2))
            Spacer()
            processingStatus
            if !appState.messages.isEmpty {
                Button {
                    appState.clearChat()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                }
                .buttonStyle(.plain)
                .help("Clear chat")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var processingStatus: some View {
        switch appState.processingState {
        case .ready:
            HStack(spacing: 4) {
                Circle().fill(Color(red: 0.157, green: 0.784, blue: 0.251)).frame(width: 5, height: 5)
                Text("Ready")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 0.157, green: 0.784, blue: 0.251))
            }
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color(red: 0.157, green: 0.784, blue: 0.251).opacity(0.12))
            .clipShape(Capsule())
        case .failed(let msg):
            Text(msg)
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 1, green: 0.373, blue: 0.341))
                .lineLimit(1)
        case .extracting, .embedding:
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                Text("Processing…")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
            }
        case .idle:
            EmptyView()
        }
    }

    // MARK: - Messages Area
    @ViewBuilder
    private var messagesArea: some View {
        if appState.messages.isEmpty {
            emptyChatState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.messages) { msg in
                            MessageBubbleView(message: msg)
                                .id(msg.id)
                        }
                        if appState.isStreaming {
                            let lastIsAssistant = appState.messages.last?.role == .assistant
                            if !lastIsAssistant || (appState.messages.last?.content.isEmpty ?? true) {
                                TypingIndicatorView()
                                    .id("typing")
                            }
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
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
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.bubble")
                .font(.system(size: 36))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651).opacity(0.5))
            Text(appState.currentDocument != nil ? "Ask a question about your document" : "Open a document to start chatting")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                .multilineTextAlignment(.center)
            if appState.currentDocument != nil && appState.processingState == .ready {
                suggestionsGrid
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var suggestionsGrid: some View {
        VStack(spacing: 6) {
            ForEach(suggestionChips, id: \.self) { chip in
                Button {
                    inputText = chip
                    isInputFocused = true
                } label: {
                    Text(chip)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.039, green: 0.518, blue: 1))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color(red: 0.039, green: 0.518, blue: 1).opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(red: 0.039, green: 0.518, blue: 1).opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private let suggestionChips = [
        "Summarize the key points",
        "What are the main topics?",
        "List the conclusions or findings"
    ]

    // MARK: - Input Bar
    @ViewBuilder
    private var inputBar: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                MultilineTextField(
                    text: $inputText,
                    isFocused: _isInputFocused,
                    placeholder: "Ask a question… (/ to focus)",
                    onSubmit: sendMessage
                )
                .frame(minHeight: 36, maxHeight: 120)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button { sendMessage() } label: {
                    Image(systemName: appState.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            canSend
                                ? Color(red: 0.039, green: 0.518, blue: 1)
                                : Color(red: 0.604, green: 0.627, blue: 0.651).opacity(0.4)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Text("⇧ Return for new line  •  / to focus")
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651).opacity(0.6))
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
        isInputFocused = true
    }
}

// MARK: - Multiline TextField (NSViewRepresentable) — FIXED

struct MultilineTextField: NSViewRepresentable {
    @Binding var text: String
    @FocusState var isFocused: Bool
    let placeholder: String
    let onSubmit: () -> Void

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
        tv.textContainerInset = NSSize(width: 0, height: 2)
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        context.coordinator.textView = tv
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? NSTextView else { return }
        if tv.string != text { tv.string = text }
        tv.textColor = NSColor.labelColor
        // Handle global "/" key press for focus via notification — no FocusState.Binding needed
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MultilineTextField
        weak var textView: NSTextView?

        init(_ parent: MultilineTextField) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }

        func textView(_ tv: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    tv.insertNewlineIgnoringFieldEditor(nil)
                    return true
                } else {
                    parent.onSubmit()
                    return true
                }
            }
            // "/" key focuses when field is not first responder via notification
            return false
        }
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    @EnvironmentObject var appState: AppState
    let message: ChatMessage
    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isUser { Spacer(minLength: 44) }
            if !isUser { aiAvatar }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                bubbleBody
                if !message.sourcePages.isEmpty && !isUser {
                    pageReferences
                }
            }
            if !isUser { Spacer(minLength: 44) }
        }
    }

    @ViewBuilder
    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.039, green: 0.518, blue: 1).opacity(0.15))
                .frame(width: 26, height: 26)
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(red: 0.039, green: 0.518, blue: 1))
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
                .background(Color(red: 0.157, green: 0.784, blue: 0.251))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            FormattedResponseView(text: message.content, isStreaming: message.isStreaming)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private var pageReferences: some View {
        HStack(spacing: 4) {
            Text("Sources:")
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
            ForEach(message.sourcePages, id: \.self) { page in
                Button {
                    appState.jumpToPage = page
                } label: {
                    Text("p.\(page)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(red: 0.039, green: 0.518, blue: 1))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(red: 0.039, green: 0.518, blue: 1).opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 34)
    }
}

// MARK: - Formatted Response View

struct FormattedResponseView: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let attributed = try? AttributedString(markdown: text,
               options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                Text(attributed)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isStreaming && !text.isEmpty {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.039, green: 0.518, blue: 1))
                    .frame(width: 6, height: 13)
                    .opacity(0.8)
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var phase = 0
    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.039, green: 0.518, blue: 1).opacity(0.15))
                    .frame(width: 26, height: 26)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 0.039, green: 0.518, blue: 1))
            }
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color(red: 0.039, green: 0.518, blue: 1).opacity(phase == i ? 0.9 : 0.25))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: false)) {
                phase = 2
            }
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Notification extension for "/" focus

extension Notification.Name {
    static let focusChatInput = Notification.Name("focusChatInput")
}
