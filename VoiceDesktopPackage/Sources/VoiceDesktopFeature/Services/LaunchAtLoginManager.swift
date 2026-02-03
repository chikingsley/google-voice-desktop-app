import Foundation
import ServiceManagement

/// Manages launch at login using SMAppService (macOS 13+)
@MainActor
public final class LaunchAtLoginManager: Sendable {
    public static let shared = LaunchAtLoginManager()
    
    private init() {}
    
    /// Returns whether the app is registered to launch at login
    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
    
    /// Returns the current status of the launch at login registration
    public var status: SMAppService.Status {
        SMAppService.mainApp.status
    }
    
    /// Enables or disables launch at login
    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    // Already enabled
                    return
                }
                try SMAppService.mainApp.register()
                print("Successfully registered for launch at login")
            } else {
                if SMAppService.mainApp.status != .enabled {
                    // Already disabled
                    return
                }
                try SMAppService.mainApp.unregister()
                print("Successfully unregistered from launch at login")
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
    
    /// Opens System Settings to the Login Items pane
    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
