import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.surfacePrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                HeaderBar()
                Divider()
                mainContent
            }
            // Toast overlay
            if appState.showToast {
                toastBanner
            }
        }
        .preferredColorScheme(appState.preferredColorScheme)
        .sheet(isPresented: $appState.showSettings) {
            SettingsView().environmentObject(appState)
        }
        .onAppear { appState.fetchModels() }
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
    private var toastBanner: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.successGreen)
                Text(appState.toastMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(response: 0.4), value: appState.showToast)
    }
}
