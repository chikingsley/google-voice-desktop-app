import SwiftUI
import VoiceDesktopFeature
import AppKit

@main
struct VoiceDesktopApp: App {
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager()
    @State private var notificationObserver = NotificationObserver()
    @State private var agentBridge: AgentBridge
    
    @AppStorage("startMinimized") private var startMinimized: Bool = false
    @AppStorage("exitOnClose") private var exitOnClose: Bool = false
    @AppStorage("agentPort") private var agentPort: Int = 3000
    
    init() {
        let storedPort = UserDefaults.standard.object(forKey: "agentPort") as? Int ?? 3000
        let validPort = (1...65535).contains(storedPort) ? storedPort : 3000
        
        // Keep persisted setting valid so UI and server stay in sync.
        if storedPort != validPort {
            UserDefaults.standard.set(validPort, forKey: "agentPort")
        }
        
        _agentBridge = State(initialValue: AgentBridge(port: validPort))
    }
    
    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView(
                appState: appState,
                themeManager: themeManager,
                notificationObserver: notificationObserver,
                agentBridge: agentBridge
            )
            .onAppear {
                if startMinimized {
                    // Hide window on first launch if start minimized is enabled
                    DispatchQueue.main.async {
                        NSApp.mainWindow?.close()
                    }
                }
                
                Task { @MainActor in
                    guard !agentBridge.isRunning else { return }
                    do {
                        try await agentBridge.start()
                    } catch {
                        print("Failed to start agent bridge: \(error)")
                    }
                }
            }
            .onChange(of: agentPort) { _, newPort in
                Task { @MainActor in
                    do {
                        try await agentBridge.updatePort(newPort)
                    } catch {
                        print("Failed to update agent bridge port: \(error)")
                        agentPort = agentBridge.port
                    }
                }
            }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 900)
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("Reload") {
                    reloadWebView()
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("Open in Browser") {
                    if let url = URL(string: "https://voice.google.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            
            // Help menu
            CommandGroup(replacing: .help) {
                Button("Voice Desktop Help") {
                    if let url = URL(string: "https://github.com/Jerrkawz/google-voice-desktop-app") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Divider()
                
                Button("Report a Bug") {
                    if let url = URL(string: "https://github.com/Jerrkawz/google-voice-desktop-app/issues/new?labels=bug") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button("Request a Feature") {
                    if let url = URL(string: "https://github.com/Jerrkawz/google-voice-desktop-app/issues/new?labels=enhancement") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        
        // Menu bar extra (macOS 13+)
        MenuBarExtra("Voice Desktop", systemImage: appState.menuBarIcon) {
            Button("Open Voice Desktop") {
                showMainWindow()
            }
            .keyboardShortcut("o")
            
            Button("Reload") {
                reloadWebView()
            }
            .keyboardShortcut("r")
            
            Divider()
            
            if appState.notificationCount > 0 {
                Text("\(appState.notificationCount) notification\(appState.notificationCount == 1 ? "" : "s")")
                    .font(.caption)
                
                Divider()
            }
            
            if agentBridge.isRunning {
                Text("Agent server: http://localhost:\(agentBridge.port)")
                    .font(.caption)
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
        .menuBarExtraStyle(.menu)
        
        // Settings window (macOS 11+)
        Settings {
            SettingsView()
        }
    }
    
    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    private func reloadWebView() {
        // Post notification for reload
        NotificationCenter.default.post(name: Notification.Name.reloadWebView, object: nil)
    }
}
