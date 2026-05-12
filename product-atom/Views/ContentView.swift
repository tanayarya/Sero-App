import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            if appState.hasCompletedOnboarding {
                VStack(spacing: 0) {
                    HeaderBar()
                    Divider()
                    mainContent
                }
                toastOverlay
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(appState.preferredColorScheme)
        .sheet(isPresented: $appState.showSettings) {
            SettingsView().environmentObject(appState)
        }
        .sheet(isPresented: $appState.showHowItWorks) {
            HowItWorksView().environmentObject(appState)
        }
        .onAppear {
            appState.fetchModels()
            if !appState.hasCompletedOnboarding {
                Task { await appState.refreshRuntimeStatus() }
            }
        }
        .onKeyPress("/") {
            NotificationCenter.default.post(name: .focusChatInput, object: nil)
            return .handled
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if appState.currentDocument != nil {
            WorkspaceView()
        } else {
            HomeView()
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if appState.showToast {
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(red: 0.157, green: 0.784, blue: 0.251))
                    Text(appState.toastMessage)
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .animation(.spring(response: 0.4), value: appState.showToast)
        }
    }
}
