import SwiftUI
import WebKit

/// Observes and polls the Google Voice DOM for notification badges
@Observable
@MainActor
public final class NotificationObserver {
    public var notificationCount: Int = 0
    public var lastPollTime: Date?
    
    private var pollTimer: Timer?
    private weak var webView: WKWebView?
    private var onNotificationCountChanged: (@MainActor (Int) -> Void)?
    
    /// Poll interval in seconds
    public static let pollInterval: TimeInterval = 3.0
    
    public init() {}
    
    /// Starts polling for notifications
    public func startPolling(webView: WKWebView, onCountChanged: @escaping @MainActor (Int) -> Void) {
        self.webView = webView
        self.onNotificationCountChanged = onCountChanged
        
        // Poll immediately
        pollNotifications()
        
        // Set up recurring timer on main run loop
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollNotifications()
            }
        }
    }
    
    /// Stops polling for notifications
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        webView = nil
        onNotificationCountChanged = nil
    }
    
    /// Polls the DOM for notification badge counts
    private func pollNotifications() {
        guard let webView = webView else { return }
        
        // JavaScript to query notification badges from Google Voice DOM
        let js = """
        (function() {
            var badges = document.querySelectorAll('.gv_root .navListItem .navItemBadge');
            var total = 0;
            badges.forEach(function(badge) {
                var text = badge.textContent && badge.textContent.trim();
                if (text) {
                    var num = parseInt(text, 10);
                    if (!isNaN(num)) total += num;
                }
            });
            return total;
        })();
        """
        
        webView.evaluateJavaScript(js) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                self.lastPollTime = Date()
                
                if let error = error {
                    print("Notification poll error: \(error)")
                    return
                }
                
                if let count = result as? Int {
                    let oldCount = self.notificationCount
                    self.notificationCount = count
                    
                    if count != oldCount {
                        self.onNotificationCountChanged?(count)
                    }
                }
            }
        }
        
        // Also check for blank page
        checkForBlankPage(webView: webView)
    }
    
    /// Checks if the page has become blank
    private func checkForBlankPage(webView: WKWebView) {
        let js = "document.querySelector('body').childNodes.length"
        
        webView.evaluateJavaScript(js) { result, error in
            Task { @MainActor in
                if let count = result as? Int, count == 0 {
                    // Page is blank, reload Google Voice
                    print("Blank page detected, reloading...")
                    if let url = URL(string: "https://voice.google.com") {
                        webView.load(URLRequest(url: url))
                    }
                }
            }
        }
    }
}
