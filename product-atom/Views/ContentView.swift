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
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
                .environmentObject(appState)
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
}
