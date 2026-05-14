import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    @State private var useRemoteServer = false
    @State private var customURL = ""
    @State private var selectedStarterModel = StarterModel.qwenCoder7b
    @State private var hasAppeared = false

    private var isDark: Bool { colorScheme == .dark }
    private let onboardingBlue = Color(red: 0.039, green: 0.518, blue: 1)

    var body: some View {
        ZStack {
            background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    hero
                    connectionCards
                    if useRemoteServer {
                        remoteSetupCard
                    } else {
                        localSetupCard
                    }
                    footerActions
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)
                .padding(.bottom, 28)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            customURL = appState.ollamaURL
            Task { await appState.refreshRuntimeStatus() }
        }
    }

    private var background: some View {
        ZStack {
            (isDark ? Color.black : Color.white).ignoresSafeArea()
            RadialGradient(
                colors: [
                    Color(red: 0.039, green: 0.518, blue: 1).opacity(isDark ? 0.24 : 0.18),
                    .clear
                ],
                center: .init(x: 0.18, y: 0.18),
                startRadius: 0,
                endRadius: 480
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.83, blue: 0.9).opacity(isDark ? 0.12 : 0.1),
                    .clear
                ],
                center: .init(x: 0.86, y: 0.2),
                startRadius: 0,
                endRadius: 460
            )
            .ignoresSafeArea()
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(height: 38)
                .padding(.top, 6)
            Text("Set up a local runtime or connect to another machine to start chatting with your documents.")
                .font(.system(size: 15))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 640)
        }
    }

    private var connectionCards: some View {
        HStack(spacing: 16) {
            modeCard(
                title: "Use this Mac",
                detail: "Recommended for private offline chat with local models.",
                icon: "laptopcomputer",
                isSelected: !useRemoteServer
            ) {
                useRemoteServer = false
                Task { await appState.refreshRuntimeStatus() }
            }

            modeCard(
                title: "Use another server",
                detail: "Connect to an Ollama server on your network or another machine.",
                icon: "network",
                isSelected: useRemoteServer
            ) {
                useRemoteServer = true
                appState.resetOnboardingStatus()
            }
        }
    }

    private func modeCard(title: String, detail: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? onboardingBlue.opacity(0.18) : Color.white.opacity(isDark ? 0.06 : 0.8))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? onboardingBlue : (isDark ? .white : Color.black.opacity(0.75)))
                }
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isDark ? .white : Color(red: 0.08, green: 0.1, blue: 0.14))
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(cardFill(selected: isSelected))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(isSelected ? onboardingBlue.opacity(0.7) : borderColor, lineWidth: isSelected ? 1.4 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private var localSetupCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Local setup")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(isDark ? .white : Color(red: 0.08, green: 0.1, blue: 0.14))
                    if case .ready = appState.localRuntimeState {
                        EmptyView()
                    } else {
                        Text(localSummary)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                    }
                }
                Spacer()
                statusBadge
            }

            if case .missing = appState.localRuntimeState {
                stepsBlock(
                    title: "Install Ollama",
                    detail: "Open the official download page, install Ollama, then come back here and click Check again."
                )
                HStack(spacing: 12) {
                    primaryButton("Open download page") {
                        appState.openOllamaDownloadPage()
                    }
                    secondaryButton("Check again") {
                        Task { await appState.refreshRuntimeStatus() }
                    }
                }
            } else if case .installed = appState.localRuntimeState {
                stepsBlock(
                    title: "Open Ollama",
                    detail: "Ollama is installed on this Mac. Open it once so the local API can start, then check again here."
                )
                HStack(spacing: 12) {
                    primaryButton("Open Ollama") {
                        appState.openInstalledOllama()
                    }
                    secondaryButton("Check again") {
                        Task { await appState.refreshRuntimeStatus() }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose your starter model")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isDark ? .white : Color(red: 0.08, green: 0.1, blue: 0.14))
                    VStack(spacing: 12) {
                        ForEach(StarterModel.allCases, id: \.self) { model in
                            starterCard(model)
                        }
                    }
                }

                if showInlineLocalStatus {
                    inlineStatusRow
                }

                HStack(spacing: 12) {
                    if hasDetectedChatModels {
                        primaryButton("Continue with current models") {
                            Task {
                                await appState.refreshModelsAndConnection()
                                if appState.ollamaConnected {
                                    appState.completeOnboarding()
                                }
                            }
                        }
                        .disabled(appState.onboardingIsPulling)

                        secondaryButton(appState.onboardingIsPulling ? "Downloading model" : "Download selected model") {
                            appState.beginStarterModelDownload(chatModel: selectedStarterModel.modelName)
                        }
                        .disabled(appState.onboardingIsPulling)
                    } else {
                        primaryButton(appState.onboardingIsPulling ? "Downloading model" : "Download selected model") {
                            appState.beginStarterModelDownload(chatModel: selectedStarterModel.modelName)
                        }
                        .disabled(appState.onboardingIsPulling)

                        secondaryButton("Refresh models") {
                            Task { await appState.refreshModelsAndConnection() }
                        }
                        .disabled(appState.onboardingIsPulling)
                    }
                }

                if hasDetectedChatModels {
                    currentModelsStrip
                }
            }
        }
        .padding(24)
        .background(cardFill(selected: true))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var remoteSetupCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Remote server")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(isDark ? .white : Color(red: 0.08, green: 0.1, blue: 0.14))
                    Text("Enter an Ollama server address, validate it, then continue with the models on that machine.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                }
                Spacer()
                if appState.onboardingIsChecking {
                    ProgressView()
                        .controlSize(.small)
                        .tint(onboardingBlue)
                        .padding(.top, 8)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Server URL")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("http://192.168.1.40:11434", text: $customURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            HStack(spacing: 12) {
                primaryButton("Validate server") {
                    Task { await appState.validateRemoteServer(urlString: customURL) }
                }
                secondaryButton("Use local URL") {
                    customURL = "http://localhost:11434"
                }
            }

            if showRemoteStatusLine {
                inlineStatusRow
            }

            if !appState.availableModels.isEmpty && appState.ollamaConnected {
                remoteModelsSection
            }
        }
        .padding(24)
        .background(cardFill(selected: true))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var currentModelsStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current models on this Mac")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isDark ? .white : Color(red: 0.08, green: 0.1, blue: 0.14))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(detectedChatModels.prefix(4)) { model in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(onboardingBlue.opacity(0.18))
                            .frame(width: 30, height: 30)
                            .overlay {
                                Image(systemName: "cpu")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(onboardingBlue)
                            }
                        Text(model.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isDark ? .white : Color(red: 0.08, green: 0.1, blue: 0.14))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var remoteModelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select a chat model")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isDark ? .white : Color(red: 0.08, green: 0.1, blue: 0.14))
            ForEach(remoteChatModels, id: \.name) { model in
                remoteModelRow(model)
            }
            primaryButton("Continue") {
                if appState.selectedModel.isEmpty, let first = remoteChatModels.first {
                    appState.selectedModel = first.name
                }
                appState.completeOnboarding()
            }
            .disabled(remoteChatModels.isEmpty)
        }
    }

    private func starterCard(_ model: StarterModel) -> some View {
        Button {
            selectedStarterModel = model
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(model.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isDark ? .white : Color(red: 0.08, green: 0.1, blue: 0.14))
                        if model.isRecommended {
                            miniBadge("Best")
                        }
                    }
                    Text(model.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        infoChip(model.ramLabel)
                        if let note = model.note {
                            infoChip(note)
                        }
                    }
                }
                Spacer(minLength: 12)
                HStack {
                    VStack(alignment: .trailing, spacing: 10) {
                        Text(model.memoryTag)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isDark ? Color.white.opacity(0.86) : Color.black.opacity(0.76))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                            .clipShape(Capsule())
                        Spacer(minLength: 0)
                    }
                    if selectedStarterModel == model {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(onboardingBlue)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardFill(selected: selectedStarterModel == model))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(selectedStarterModel == model ? onboardingBlue.opacity(0.7) : borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func remoteModelRow(_ model: OllamaModel) -> some View {
        Button {
            appState.selectedModel = model.name
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(onboardingBlue.opacity(0.18))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "cpu")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(onboardingBlue)
                    }
                Text(model.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isDark ? .white : Color(red: 0.08, green: 0.1, blue: 0.14))
                    .lineLimit(1)
                Spacer()
                if appState.selectedModel == model.name {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(onboardingBlue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.035))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(appState.selectedModel == model.name ? onboardingBlue.opacity(0.6) : borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var footerActions: some View {
        HStack {
            Text("You can always change this later in Settings.")
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
            Spacer()
            Button("Skip for now") {
                appState.completeOnboarding()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isDark ? .white : Color.black.opacity(0.75))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isDark ? Color.white.opacity(0.09) : Color.black.opacity(0.09))
            .overlay(
                Capsule()
                    .strokeBorder(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
    }

    private func stepsBlock(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isDark ? .white : Color(red: 0.08, green: 0.1, blue: 0.14))
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isDark ? .white : Color.black.opacity(0.75))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
        .clipShape(Capsule())
    }

    private var localSummary: String {
        switch appState.localRuntimeState {
        case .checking:
            return "Checking for a local Ollama setup on this Mac."
        case .missing:
            return "Ollama is not installed yet. We can guide you to the official download."
        case .installed:
            return "Ollama is installed. Open it once, then come back here."
        case .ready:
            return "Ollama is running and ready for model setup."
        }
    }

    private var statusLabel: String {
        switch appState.localRuntimeState {
        case .checking: return "Checking"
        case .missing: return "Not installed"
        case .installed: return "Installed"
        case .ready: return "Ready"
        }
    }

    private var statusColor: Color {
        switch appState.localRuntimeState {
        case .checking: return Color.warningAmber
        case .missing: return Color.errorRed
        case .installed: return Color.warningAmber
        case .ready: return Color.successGreen
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(onboardingBlue)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isDark ? .white : Color.black.opacity(0.75))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func cardFill(selected: Bool) -> some ShapeStyle {
        LinearGradient(
            colors: selected
                ? [
                    isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.98),
                    isDark ? Color.white.opacity(0.04) : Color(red: 0.96, green: 0.98, blue: 1)
                ]
                : [
                    isDark ? Color.white.opacity(0.04) : Color.white.opacity(0.92),
                    isDark ? Color.white.opacity(0.025) : Color(red: 0.97, green: 0.97, blue: 0.99)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderColor: Color {
        isDark ? Color.white.opacity(0.09) : Color.black.opacity(0.07)
    }

    private var remoteChatModels: [OllamaModel] {
        appState.availableModels.filter { !isEmbeddingName($0.name) }
    }

    private var detectedChatModels: [OllamaModel] {
        appState.availableModels.filter { !isEmbeddingName($0.name) }
    }

    private var hasDetectedChatModels: Bool {
        !detectedChatModels.isEmpty
    }

    private var showInlineLocalStatus: Bool {
        appState.onboardingIsPulling || (appState.onboardingStatusMessage?.isEmpty == false)
    }

    private var showRemoteStatusLine: Bool {
        appState.onboardingIsChecking || (appState.onboardingStatusMessage?.isEmpty == false)
    }

    private var inlineStatusRow: some View {
        HStack(spacing: 10) {
            if appState.onboardingIsPulling || appState.onboardingIsChecking {
                ProgressView()
                    .controlSize(.small)
                    .tint(onboardingBlue)
            }
            VStack(alignment: .leading, spacing: 4) {
                if let message = appState.onboardingStatusMessage, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isDark ? .white.opacity(0.92) : Color.black.opacity(0.78))
                }
                if let detail = appState.onboardingDetailText, !detail.isEmpty, appState.onboardingIsPulling {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                }
            }
            Spacer()
            if let progress = appState.onboardingProgress, appState.onboardingIsPulling {
                ProgressView(value: progress)
                    .frame(width: 120)
                    .tint(onboardingBlue)
            }
            if appState.onboardingIsPulling {
                Button("Cancel") {
                    appState.cancelOnboardingDownload()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isDark ? .white : Color.black.opacity(0.72))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isDark ? Color.white.opacity(0.045) : Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func isEmbeddingName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("embed") || lower.contains("nomic") || lower.contains("mxbai")
    }

    private func infoChip(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
            .clipShape(Capsule())
    }

    private func miniBadge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(onboardingBlue)
            .clipShape(Capsule())
    }
}

enum StarterModel: String, CaseIterable, Equatable {
    case qwen3b
    case llama3b
    case qwenCoder7b
    case llama8b

    var title: String {
        switch self {
        case .qwen3b: return "Qwen 2.5 3B"
        case .llama3b: return "Llama 3.2 3B"
        case .qwenCoder7b: return "Qwen 2.5 Coder 7B"
        case .llama8b: return "Llama 3.1 8B"
        }
    }

    var summary: String {
        switch self {
        case .qwen3b:
            return "A compact model for lightweight document chat on smaller machines."
        case .llama3b:
            return "A smooth low memory option for quick answers and summaries."
        case .qwenCoder7b:
            return "A strong all around pick with excellent reasoning and solid document understanding."
        case .llama8b:
            return "A larger local model with stronger answers when you have more memory available."
        }
    }

    var modelName: String {
        switch self {
        case .qwen3b: return "qwen2.5:3b"
        case .llama3b: return "llama3.2:3b"
        case .qwenCoder7b: return "qwen2.5-coder:7b"
        case .llama8b: return "llama3.1:8b"
        }
    }

    var memoryTag: String {
        switch self {
        case .qwen3b, .llama3b:
            return "8 GB"
        case .qwenCoder7b, .llama8b:
            return "16 GB+"
        }
    }

    var ramLabel: String {
        switch self {
        case .qwen3b, .llama3b:
            return "Best for 8 GB RAM"
        case .qwenCoder7b, .llama8b:
            return "Best for 16 GB or more"
        }
    }

    var note: String? {
        switch self {
        case .qwen3b:
            return "Fast"
        case .llama3b:
            return "Simple"
        case .qwenCoder7b:
            return "Recommended"
        case .llama8b:
            return "Higher quality"
        }
    }

    var isRecommended: Bool {
        self == .qwenCoder7b
    }
}
