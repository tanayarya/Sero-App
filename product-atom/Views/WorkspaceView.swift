import SwiftUI

struct WorkspaceView: View {
    var body: some View {
        HSplitView {
            DocumentViewerPanel()
                .frame(minWidth: 360)
            ChatPanel()
                .frame(minWidth: 300)
        }
    }
}
