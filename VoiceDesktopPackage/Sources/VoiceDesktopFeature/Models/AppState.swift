import SwiftUI
import AppKit

/// Central application state using @Observable macro (macOS 14+)
@Observable
@MainActor
public final class AppState {
    public var notificationCount: Int = 0
    public var currentTheme: Theme = .default
    public var isWebViewLoaded: Bool = false
    public var webViewError: String?
    
    /// Icon name for the menu bar - changes based on notification count
    public var menuBarIcon: String {
        notificationCount > 0 ? "phone.fill.badge.plus" : "phone.fill"
    }
    
    public init() {}
    
    /// Updates the dock badge with the current notification count
    public func updateDockBadge() {
        if notificationCount > 0 {
            NSApp.dockTile.badgeLabel = "\(notificationCount)"
        } else {
            NSApp.dockTile.badgeLabel = nil
        }
    }
    
    /// Bounces the dock icon to get user attention
    public func bounceDockIcon() {
        NSApp.requestUserAttention(.informationalRequest)
    }
}

/// Available themes for the application
public enum Theme: String, CaseIterable, Identifiable, Codable {
    case `default` = "default"
    case dracula = "dracula"
    case solar = "solar"
    case minty = "minty"
    case cerulean = "cerulean"
    case darkplus = "darkplus"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .default: return "Default"
        case .dracula: return "Dracula"
        case .solar: return "Solar"
        case .minty: return "Minty"
        case .cerulean: return "Cerulean"
        case .darkplus: return "DarkPlus"
        }
    }
}
