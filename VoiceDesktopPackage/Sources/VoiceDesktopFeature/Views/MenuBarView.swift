import SwiftUI

/// Menu bar dropdown content
public struct MenuBarView: View {
    var appState: AppState
    var onReload: () -> Void
    var onOpenWindow: () -> Void
    
    public init(
        appState: AppState,
        onReload: @escaping () -> Void,
        onOpenWindow: @escaping () -> Void
    ) {
        self.appState = appState
        self.onReload = onReload
        self.onOpenWindow = onOpenWindow
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Button("Open Voice Desktop") {
                onOpenWindow()
            }
            .keyboardShortcut("o")
            
            Button("Reload") {
                onReload()
            }
            .keyboardShortcut("r")
            
            Divider()
            
            if appState.notificationCount > 0 {
                Text("\(appState.notificationCount) notification\(appState.notificationCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Divider()
            }
            
            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",")
            
            Divider()
            
            Button("Quit Voice Desktop") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
