import SwiftUI

/// Settings view using @AppStorage for persistence
public struct SettingsView: View {
    @AppStorage("theme") private var theme: String = Theme.default.rawValue
    @AppStorage("startAtLogin") private var startAtLogin: Bool = false
    @AppStorage("startMinimized") private var startMinimized: Bool = false
    @AppStorage("exitOnClose") private var exitOnClose: Bool = false
    @AppStorage("hideDialerSidebar") private var hideDialerSidebar: Bool = false
    @AppStorage("zoomLevel") private var zoomLevel: Double = 1.0
    @AppStorage("agentPort") private var agentPort: Int = 3000
    
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            agentTab
                .tabItem {
                    Label("Agent", systemImage: "network")
                }
        }
        .frame(width: 450, height: 300)
        .padding()
    }
    
    private var generalTab: some View {
        Form {
            Section {
                Toggle("Start at Login", isOn: $startAtLogin)
                    .onChange(of: startAtLogin) { _, newValue in
                        LaunchAtLoginManager.shared.setEnabled(newValue)
                    }
                
                Toggle("Start Minimized", isOn: $startMinimized)
                    .help("Start the app minimized to the menu bar")
                
                Toggle("Exit on Close", isOn: $exitOnClose)
                    .help("Quit the app when the window is closed instead of hiding to menu bar")
            } header: {
                Text("Startup")
            }
        }
        .formStyle(.grouped)
    }
    
    private var appearanceTab: some View {
        Form {
            Section {
                Picker("Theme", selection: $theme) {
                    ForEach(Theme.allCases) { themeOption in
                        Text(themeOption.displayName).tag(themeOption.rawValue)
                    }
                }
                .pickerStyle(.menu)
                
                Toggle("Hide Dialer Sidebar", isOn: $hideDialerSidebar)
                    .help("Hide the sidebar when in the dialer view")
            } header: {
                Text("Theme")
            }
            
            Section {
                HStack {
                    Text("Zoom")
                    Slider(value: $zoomLevel, in: 0.5...2.0, step: 0.1)
                    Text("\(Int(zoomLevel * 100))%")
                        .frame(width: 50)
                }
                
                Button("Reset Zoom") {
                    zoomLevel = 1.0
                }
            } header: {
                Text("Display")
            }
        }
        .formStyle(.grouped)
    }
    
    private var agentTab: some View {
        Form {
            Section {
                HStack {
                    Text("WebSocket Port")
                    Spacer()
                    TextField("Port", value: $agentPort, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }
                
                Text("Agents can connect via ws://localhost:\(agentPort)/agent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Agent Server")
            }
            
            Section {
                Text("The agent server allows external programs to control Voice Desktop via WebSocket.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Commands: makeCall, sendSMS, getStatus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Events: callInitiated, messageReceived, incomingCall, etc.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
}
