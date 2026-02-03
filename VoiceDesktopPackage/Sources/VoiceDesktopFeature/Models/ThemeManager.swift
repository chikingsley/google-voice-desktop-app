import SwiftUI
import WebKit

/// Manages theme CSS injection into WKWebView
@Observable
@MainActor
public final class ThemeManager {
    public var currentTheme: Theme = .default
    private var injectedStyleKey: String?
    
    public init() {}
    
    /// Injects the current theme CSS into the web view
    public func injectTheme(into webView: WKWebView) {
        // First remove any existing injected styles
        removeInjectedStyles(from: webView)
        
        guard currentTheme != .default else { return }
        
        let css = getCSSForTheme(currentTheme)
        let js = """
        (function() {
            var style = document.createElement('style');
            style.id = 'voice-desktop-theme';
            style.textContent = `\(css)`;
            document.head.appendChild(style);
        })();
        """
        
        webView.evaluateJavaScript(js) { [weak self] _, error in
            Task { @MainActor [weak self] in
                if let error = error {
                    print("Theme injection error: \(error)")
                } else {
                    self?.injectedStyleKey = "voice-desktop-theme"
                }
            }
        }
    }
    
    /// Removes injected styles from the web view
    public func removeInjectedStyles(from webView: WKWebView) {
        let js = """
        (function() {
            var style = document.getElementById('voice-desktop-theme');
            if (style) style.remove();
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
        injectedStyleKey = nil
    }
    
    /// Injects CSS to hide the dialer sidebar
    public func setDialerSidebarHidden(_ hidden: Bool, in webView: WKWebView) {
        if hidden {
            let js = """
            (function() {
                var style = document.getElementById('voice-desktop-sidebar-hide');
                if (!style) {
                    style = document.createElement('style');
                    style.id = 'voice-desktop-sidebar-hide';
                    style.textContent = 'gv-call-sidebar { display: none !important; }';
                    document.head.appendChild(style);
                }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        } else {
            let js = """
            (function() {
                var style = document.getElementById('voice-desktop-sidebar-hide');
                if (style) style.remove();
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    /// Returns the CSS string for a given theme
    private func getCSSForTheme(_ theme: Theme) -> String {
        switch theme {
        case .default:
            return ""
        case .dracula:
            return ThemeCSS.dracula
        case .solar:
            return ThemeCSS.solar
        case .minty:
            return ThemeCSS.minty
        case .cerulean:
            return ThemeCSS.cerulean
        case .darkplus:
            return ThemeCSS.darkplus
        }
    }
}

/// Pre-compiled CSS strings for each theme
/// These are converted from the original SCSS themes
public enum ThemeCSS {
    public static let dracula = """
    /* Dracula Theme */
    header { background-color: #282a36 !important; }
    header [title='Google Voice'] > span { color: #f8f8f2 !important; }
    header form[role='search'] { background-color: #282a36 !important; }
    gv-side-nav { background-color: #282a36 !important; border-right: 1px solid #f8f8f2 !important; }
    gmat-nav-list .navListItem, gmat-nav-list .navListItem svg { color: #f8f8f2 !important; }
    gv-side-nav a.navListItem.gmat-list-item-active { background-color: #44475a !important; }
    gv-side-nav a.navListItem.gmat-list-item-active svg { color: #f8f8f2 !important; }
    [role='tablist']:not(.expanded) .navItemBadge { background-color: #6272a4 !important; }
    gv-message-list, gv-voicemail-player md-content, gv-inbox-summary-ng2, gv-thread-details, gv-messaging-view md-content { color: #f8f8f2 !important; background-color: #282a36 !important; }
    gv-message-list-header > div { background-color: #282a36 !important; }
    gv-message-entry > div { color: #f8f8f2 !important; background-color: #282a36 !important; }
    gv-message-item [layout-align='start start'] [gv-test-id='bubble'] { color: #f8f8f2 !important; background-color: #bd93f9 !important; border-radius: 2rem !important; }
    gv-message-item [layout-align='start end'] [gv-test-id='bubble'] { color: #f8f8f2 !important; background-color: #6272a4 !important; border-radius: 2rem !important; }
    gv-conversation-list, #contact-list, body > [role='listbox'] { background-color: #282a36 !important; }
    gv-thread-item > div, [gv-test-id='send-new-message'], gv-recipient-picker md-content, gv-recipient-picker > div, gv-call-as-banner, gv-thread > div, gv-make-call-panel-ng2 > div > div:nth-child(2), gv-contact-item > div, gv-contact-card, gv-frequent-contact-card > div { background-color: #282a36 !important; color: #f8f8f2 !important; }
    gv-thread-item > div.layout-row[aria-selected='true'] { background-color: #44475a !important; }
    gv-dialpad > div { background-color: #282a36 !important; }
    gv-dialpad [role='gridcell'] > div, gv-dialpad [role='gridcell'] .gmat-caption { color: #f8f8f2 !important; }
    gv-dialpad-toggle button { background-color: #282a36 !important; color: #f8f8f2 !important; }
    """
    
    public static let solar = """
    /* Solar Theme */
    header { background-color: #002b36 !important; }
    header [title='Google Voice'] > span { color: #839496 !important; }
    header form[role='search'] { background-color: #002b36 !important; }
    gv-side-nav { background-color: #002b36 !important; }
    gmat-nav-list .navListItem, gmat-nav-list .navListItem svg { color: #839496 !important; }
    gv-side-nav a.navListItem.gmat-list-item-active { background-color: #073642 !important; }
    [role='tablist']:not(.expanded) .navItemBadge { background-color: #268bd2 !important; }
    gv-message-list, gv-voicemail-player md-content, gv-inbox-summary-ng2, gv-thread-details, gv-messaging-view md-content { color: #839496 !important; background-color: #002b36 !important; }
    gv-message-list-header > div { background-color: #002b36 !important; }
    gv-message-entry > div { color: #839496 !important; background-color: #002b36 !important; }
    gv-message-item [layout-align='start start'] [gv-test-id='bubble'] { color: #839496 !important; background-color: #2aa198 !important; border-radius: 2rem !important; }
    gv-message-item [layout-align='start end'] [gv-test-id='bubble'] { color: #839496 !important; background-color: #268bd2 !important; border-radius: 2rem !important; }
    gv-conversation-list, #contact-list, body > [role='listbox'] { background-color: #002b36 !important; }
    gv-thread-item > div, gv-contact-item > div, gv-contact-card, gv-frequent-contact-card > div { background-color: #002b36 !important; color: #839496 !important; }
    gv-thread-item > div.layout-row[aria-selected='true'] { background-color: #073642 !important; }
    gv-dialpad > div { background-color: #002b36 !important; }
    gv-dialpad [role='gridcell'] > div { color: #839496 !important; }
    """
    
    public static let minty = """
    /* Minty Theme */
    header { background-color: #78c2ad !important; }
    header [title='Google Voice'] > span { color: #fff !important; }
    header form[role='search'] { background-color: #78c2ad !important; }
    gv-side-nav { background-color: #78c2ad !important; }
    gmat-nav-list .navListItem, gmat-nav-list .navListItem svg { color: #fff !important; }
    gv-side-nav a.navListItem.gmat-list-item-active { background-color: #5a9a8a !important; }
    [role='tablist']:not(.expanded) .navItemBadge { background-color: #f3969a !important; }
    gv-message-list, gv-voicemail-player md-content, gv-inbox-summary-ng2, gv-thread-details { color: #5a5a5a !important; background-color: #fff !important; }
    gv-message-item [layout-align='start start'] [gv-test-id='bubble'] { color: #fff !important; background-color: #6cc3d5 !important; border-radius: 2rem !important; }
    gv-message-item [layout-align='start end'] [gv-test-id='bubble'] { color: #fff !important; background-color: #78c2ad !important; border-radius: 2rem !important; }
    """
    
    public static let cerulean = """
    /* Cerulean Theme */
    header { background-color: #2fa4e7 !important; }
    header [title='Google Voice'] > span { color: #fff !important; }
    header form[role='search'] { background-color: #2fa4e7 !important; }
    gv-side-nav { background-color: #2fa4e7 !important; }
    gmat-nav-list .navListItem, gmat-nav-list .navListItem svg { color: #fff !important; }
    gv-side-nav a.navListItem.gmat-list-item-active { background-color: #1a7bb9 !important; }
    [role='tablist']:not(.expanded) .navItemBadge { background-color: #e9322d !important; }
    gv-message-list, gv-voicemail-player md-content, gv-inbox-summary-ng2, gv-thread-details { color: #555 !important; background-color: #fff !important; }
    gv-message-item [layout-align='start start'] [gv-test-id='bubble'] { color: #fff !important; background-color: #73a839 !important; border-radius: 2rem !important; }
    gv-message-item [layout-align='start end'] [gv-test-id='bubble'] { color: #fff !important; background-color: #2fa4e7 !important; border-radius: 2rem !important; }
    """
    
    public static let darkplus = """
    /* DarkPlus Theme (VS Code inspired) */
    header { background-color: #1e1e1e !important; }
    header [title='Google Voice'] > span { color: #d4d4d4 !important; }
    header form[role='search'] { background-color: #1e1e1e !important; }
    gv-side-nav { background-color: #252526 !important; }
    gmat-nav-list .navListItem, gmat-nav-list .navListItem svg { color: #d4d4d4 !important; }
    gv-side-nav a.navListItem.gmat-list-item-active { background-color: #37373d !important; }
    [role='tablist']:not(.expanded) .navItemBadge { background-color: #0e639c !important; }
    gv-message-list, gv-voicemail-player md-content, gv-inbox-summary-ng2, gv-thread-details, gv-messaging-view md-content { color: #d4d4d4 !important; background-color: #1e1e1e !important; }
    gv-message-list-header > div { background-color: #1e1e1e !important; }
    gv-message-entry > div { color: #d4d4d4 !important; background-color: #1e1e1e !important; }
    gv-message-item [layout-align='start start'] [gv-test-id='bubble'] { color: #d4d4d4 !important; background-color: #264f78 !important; border-radius: 2rem !important; }
    gv-message-item [layout-align='start end'] [gv-test-id='bubble'] { color: #d4d4d4 !important; background-color: #0e639c !important; border-radius: 2rem !important; }
    gv-conversation-list, #contact-list, body > [role='listbox'] { background-color: #252526 !important; }
    gv-thread-item > div, gv-contact-item > div, gv-contact-card { background-color: #252526 !important; color: #d4d4d4 !important; }
    gv-thread-item > div.layout-row[aria-selected='true'] { background-color: #37373d !important; }
    gv-dialpad > div { background-color: #1e1e1e !important; }
    gv-dialpad [role='gridcell'] > div { color: #d4d4d4 !important; }
    """
}
