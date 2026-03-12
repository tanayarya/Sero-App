import SwiftUI
import AppKit

extension Notification.Name {
    static let focusChatInput = Notification.Name("focusChatInput")
}

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
            Divider().opacity(0.3)
            messagesArea
            inputSection
        }
        .background(isDark ? Color(red: 0.055, green: 0.063, blue: 0.071) : Color.white)
        .onReceive(NotificationCenter.default.publisher(for: .focusChatInput)) { _ in
            isInputFocused = true
        }
    }

    // MARK: - Toolbar
    @ViewBuilder
    private var chatToolbar: some View {
        HStack {
            Text("Assistant")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.1, green: 0.1, blue: 0.1))
            Spacer()
            processingStatus
            if !appState.messages.isEmpty {
                Button { appState.clearChat() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(isDark ? Color.white : Color(red: 0.3, green: 0.3, blue: 0.3))
                }
                .buttonStyle(.plain).help("Clear chat")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 16)
    }

    @ViewBuilder
    private var processingStatus: some View {
        switch appState.processingState {
        case .extracting:
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                Text("Extracting…").font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
            }
        case .embedding(let p):
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                Text("Embedding \(Int(p * 100))%").font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
            }
        case .failed(let msg):
            Text(msg).font(.system(size: 10))
                .foregroundStyle(Color(red: 1, green: 0.373, blue: 0.341)).lineLimit(1)
        default: EmptyView()
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
                    LazyVStack(spacing: 4) {
                        ForEach(appState.messages) { msg in
                            MessageBubbleView(message: msg).id(msg.id)
                        }
                        typingIndicator
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 20).padding(.vertical, 20)
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
    private var typingIndicator: some View {
        if appState.isStreaming {
            let lastIsAssistant = appState.messages.last?.role == .assistant
            let lastContent = appState.messages.last?.content ?? ""
            if !lastIsAssistant || lastContent.isEmpty {
                TypingIndicatorView().id("typing")
            }
        }
    }

    @ViewBuilder
    private var emptyChatState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.bubble")
                .font(.system(size: 32))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651).opacity(0.4))
            Text(appState.currentDocument != nil
                 ? "Ask a question about your document"
                 : "Open a document to start chatting")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Input Section
    @ViewBuilder
    private var inputSection: some View {
        VStack(spacing: 8) {
            inputField
            if appState.currentDocument != nil && appState.processingState == .ready {
                suggestionsRow
            }
        }
        .padding(.top, 12)
        .background(isDark ? Color.black.opacity(0.1) : Color.black.opacity(0.02))
        .overlay(alignment: .top) {
            Rectangle().fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)).frame(height: 1)
        }
    }

    @ViewBuilder
    private var inputField: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ChatInputField(text: $inputText, placeholder: "Ask about this document…", onSubmit: sendMessage)
                .frame(minHeight: 35, maxHeight: 120)
                .padding(.leading, 10)
            HStack(spacing: 8) {
                Button { sendMessage() } label: {
                    ZStack {
                        Circle()
                            .fill(canSend ? Color(red: 0.039, green: 0.518, blue: 1) : Color(red: 0.604, green: 0.627, blue: 0.651).opacity(0.3))
                            .frame(width: 32, height: 32)
                        Image(systemName: appState.isStreaming ? "stop.fill" : "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain).disabled(!canSend)
            }
            .padding(.trailing, 4).padding(.bottom, 4)
        }
        .padding(.horizontal, 4).padding(.vertical, 4)
        .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var suggestionsRow: some View {
        let chips = ["Explain table on page 4", "Summarize document", "Find key risks"]
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(chips, id: \.self) { chip in
                    Button {
                        inputText = ""
                        appState.sendMessage(chip)
                    } label: {
                        Text(chip)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                            .overlay(Capsule()
                                .strokeBorder(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.1), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !appState.isStreaming
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !appState.isStreaming else { return }
        inputText = ""
        appState.sendMessage(trimmed)
    }
}

// MARK: - Native Chat Input (proper placeholder, not prefilled text)

struct ChatInputField: NSViewRepresentable {
    @Binding var text: String
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
        tv.textContainerInset = NSSize(width: 0, height: 8)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        context.coordinator.textView = tv
        setupPlaceholder(tv, context: context)
        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.focusFromNotification),
            name: .focusChatInput, object: nil
        )
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? NSTextView else { return }
        let isShowingPlaceholder = context.coordinator.isShowingPlaceholder
        if text.isEmpty && !isShowingPlaceholder && !context.coordinator.isEditing {
            showPlaceholder(tv, context: context)
        } else if !text.isEmpty && isShowingPlaceholder {
            tv.string = text
            tv.textColor = .labelColor
            context.coordinator.isShowingPlaceholder = false
        } else if !isShowingPlaceholder && tv.string != text {
            tv.string = text
        }
    }

    private func setupPlaceholder(_ tv: NSTextView, context: Context) {
        if text.isEmpty {
            showPlaceholder(tv, context: context)
        } else {
            tv.string = text
            tv.textColor = .labelColor
        }
    }

    private func showPlaceholder(_ tv: NSTextView, context: Context) {
        tv.string = placeholder
        tv.textColor = .placeholderTextColor
        context.coordinator.isShowingPlaceholder = true
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatInputField
        weak var textView: NSTextView?
        var isShowingPlaceholder = false
        var isEditing = false

        init(_ parent: ChatInputField) { self.parent = parent }

        func textDidBeginEditing(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            isEditing = true
            if isShowingPlaceholder {
                tv.string = ""
                tv.textColor = .labelColor
                isShowingPlaceholder = false
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            isEditing = false
            if tv.string.isEmpty {
                tv.string = parent.placeholder
                tv.textColor = .placeholderTextColor
                isShowingPlaceholder = true
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            if isShowingPlaceholder { return }
            parent.text = tv.string
        }

        func textView(_ tv: NSTextView, doCommandBy sel: Selector) -> Bool {
            if sel == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    tv.insertNewlineIgnoringFieldEditor(nil)
                    return true
                }
                if !isShowingPlaceholder && !tv.string.isEmpty {
                    parent.onSubmit()
                }
                return true
            }
            return false
        }

        @objc func focusFromNotification() {
            textView?.window?.makeFirstResponder(textView)
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
        HStack(alignment: .bottom, spacing: 12) {
            if isUser { Spacer(minLength: 60) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                bubbleContent
                if !message.sourcePages.isEmpty && !isUser { pageReferences }
            }
            if !isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if isUser {
            Text(message.content)
                .font(.system(size: 13)).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(Color(red: 0.039, green: 0.518, blue: 1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(maxWidth: 260, alignment: .trailing)
        } else {
            FormattedResponseView(text: message.content, isStreaming: message.isStreaming)
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(maxWidth: 280, alignment: .leading)
        }
    }

    @ViewBuilder
    private var pageReferences: some View {
        HStack(spacing: 4) {
            ForEach(message.sourcePages.prefix(4), id: \.self) { page in
                Button { appState.jumpToPage = page } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.text").font(.system(size: 8))
                        Text("Page \(page)").font(.system(size: 11))
                    }
                    .foregroundStyle(Color(red: 0.376, green: 0.647, blue: 1))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color(red: 0.102, green: 0.11, blue: 0.118))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Formatted Response

struct FormattedResponseView: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let attr = try? AttributedString(
                markdown: text,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                Text(attr)
                    .font(.system(size: 13)).foregroundStyle(Color.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(text)
                    .font(.system(size: 13)).foregroundStyle(Color.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if isStreaming && !text.isEmpty {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.039, green: 0.518, blue: 1))
                    .frame(width: 6, height: 13).opacity(0.8)
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var dotPhase = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color(red: 0.039, green: 0.518, blue: 1)
                            .opacity(dotPhase == i ? 0.9 : 0.25))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.4).delay(Double(i) * 0.15), value: dotPhase)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            Spacer()
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }
}
