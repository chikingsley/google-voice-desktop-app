import SwiftUI
import WebKit

/// NSViewRepresentable wrapper for WKWebView that loads Google Voice
public struct GoogleVoiceWebView: NSViewRepresentable {
    @Binding var notificationCount: Int
    var themeManager: ThemeManager
    var onWebViewCreated: ((WKWebView) -> Void)?
    
    public init(
        notificationCount: Binding<Int>,
        themeManager: ThemeManager,
        onWebViewCreated: ((WKWebView) -> Void)? = nil
    ) {
        self._notificationCount = notificationCount
        self.themeManager = themeManager
        self.onWebViewCreated = onWebViewCreated
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Enable media capture for microphone
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Add script message handler for notifications from web page
        configuration.userContentController.add(context.coordinator, name: "notificationHandler")
        
        // Inject notification click handler script
        let notificationScript = WKUserScript(
            source: Self.notificationClickScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(notificationScript)
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Enable developer tools in debug builds
        #if DEBUG
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif
        
        // Load Google Voice
        if let url = URL(string: Constants.googleVoiceURL) {
            webView.load(URLRequest(url: url))
        }
        
        // Notify coordinator
        context.coordinator.webView = webView
        onWebViewCreated?(webView)
        
        return webView
    }
    
    public func updateNSView(_ webView: WKWebView, context: Context) {
        // Inject theme when it changes
        themeManager.injectTheme(into: webView)
    }
    
    public func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(parent: self)
    }
    
    /// JavaScript to shim Notification API and handle clicks
    private static let notificationClickScript = """
    (function() {
        // Override Notification to capture clicks
        const OriginalNotification = window.Notification;
        
        window.Notification = function(title, options) {
            const notification = new OriginalNotification(title, options);
            notification.onclick = function(event) {
                window.webkit.messageHandlers.notificationHandler.postMessage({
                    type: 'notification-clicked',
                    title: title
                });
            };
            return notification;
        };
        
        // Copy static properties
        window.Notification.permission = OriginalNotification.permission;
        window.Notification.requestPermission = OriginalNotification.requestPermission.bind(OriginalNotification);
    })();
    """
}

/// Coordinator handling WKWebView delegates
public class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    var parent: GoogleVoiceWebView
    weak var webView: WKWebView?
    
    init(parent: GoogleVoiceWebView) {
        self.parent = parent
    }
    
    // MARK: - WKScriptMessageHandler
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "notificationHandler" {
            if let body = message.body as? [String: Any],
               let type = body["type"] as? String,
               type == "notification-clicked" {
                // Bring app to foreground when notification is clicked
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.mainWindow {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
            }
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    @MainActor
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else {
            return .allow
        }
        
        let host = url.host ?? ""
        
        // Allow Google Voice and Google accounts URLs internally
        if host == "voice.google.com" || host == "accounts.google.com" || host.hasSuffix(".google.com") {
            return .allow
        } else if navigationAction.navigationType == .linkActivated {
            // Open external links in default browser
            NSWorkspace.shared.open(url)
            return .cancel
        } else {
            return .allow
        }
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Re-inject theme after page load
        parent.themeManager.injectTheme(into: webView)
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        print("WebView navigation failed: \(error)")
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        print("WebView provisional navigation failed: \(error)")
    }
    
    // MARK: - WKUIDelegate
    
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Handle target="_blank" links - open in browser
        if let url = navigationAction.request.url {
            let host = url.host ?? ""
            if host == "voice.google.com" || host == "accounts.google.com" {
                // Keep Google URLs internal
                webView.load(navigationAction.request)
            } else {
                // Open others externally
                NSWorkspace.shared.open(url)
            }
        }
        return nil
    }
    
    // Handle permission requests for microphone
    @MainActor
    public func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType) async -> WKPermissionDecision {
        // Allow microphone for Google Voice
        if origin.host == "voice.google.com" {
            return .grant
        } else {
            return .prompt
        }
    }
}

/// Application constants
public enum Constants {
    public static let googleVoiceURL = "https://voice.google.com"
    public static let applicationName = "Voice Desktop"
}
