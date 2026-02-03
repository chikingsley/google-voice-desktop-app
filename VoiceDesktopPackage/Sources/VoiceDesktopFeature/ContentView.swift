import SwiftUI
import WebKit

// Debug logging helper - writes to app container and console
func debugLog(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logMessage = "[\(timestamp)] \(message)\n"
    
    // Print to console (visible in Xcode)
    print("📋 DEBUG: \(message)")
    
    // Write to app container (sandbox-safe)
    if let containerURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
        let appFolder = containerURL.appendingPathComponent("VoiceDesktop")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        let logPath = appFolder.appendingPathComponent("debug.log")
        
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath.path) {
                if let handle = try? FileHandle(forWritingTo: logPath) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logPath)
            }
        }
    }
}

/// Main content view containing the Google Voice WebView
public struct ContentView: View {
    var appState: AppState
    var themeManager: ThemeManager
    var notificationObserver: NotificationObserver
    var agentBridge: AgentBridge
    
    @AppStorage("hideDialerSidebar") private var hideDialerSidebar: Bool = false
    @AppStorage("zoomLevel") private var zoomLevel: Double = 1.0
    @AppStorage("theme") private var theme: String = Theme.default.rawValue
    
    @State private var webView: WKWebView?
    
    public init(
        appState: AppState,
        themeManager: ThemeManager,
        notificationObserver: NotificationObserver,
        agentBridge: AgentBridge
    ) {
        self.appState = appState
        self.themeManager = themeManager
        self.notificationObserver = notificationObserver
        self.agentBridge = agentBridge
    }
    
    public var body: some View {
        GoogleVoiceWebView(
            notificationCount: .init(
                get: { appState.notificationCount },
                set: { appState.notificationCount = $0 }
            ),
            themeManager: themeManager,
            onWebViewCreated: { wv in
                self.webView = wv
                setupWebView(wv)
            }
        )
        .frame(minWidth: 800, minHeight: 600)
        .onChange(of: hideDialerSidebar) { _, newValue in
            if let wv = webView {
                themeManager.setDialerSidebarHidden(newValue, in: wv)
            }
        }
        .onChange(of: zoomLevel) { _, newValue in
            webView?.pageZoom = newValue
        }
        .onChange(of: theme) { _, newValue in
            themeManager.currentTheme = Theme(rawValue: newValue) ?? .default
            if let wv = webView {
                themeManager.injectTheme(into: wv)
            }
        }
        .onAppear {
            setupAgentBridge()
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadWebView)) { _ in
            reload()
        }
    }
    
    private func setupWebView(_ webView: WKWebView) {
        debugLog("setupWebView called - WebView is ready!")
        
        // Apply initial zoom
        webView.pageZoom = zoomLevel
        
        // Apply initial theme
        themeManager.currentTheme = Theme(rawValue: theme) ?? .default
        
        // Start notification polling
        notificationObserver.startPolling(webView: webView) { count in
            let oldCount = appState.notificationCount
            appState.notificationCount = count
            appState.updateDockBadge()
            
            // Bounce dock icon if notifications increased
            if count > oldCount {
                appState.bounceDockIcon()
            }
        }
        
        // Apply hide sidebar setting
        themeManager.setDialerSidebarHidden(hideDialerSidebar, in: webView)
        
        // Register call handler now that webView exists
        debugLog("Registering onMakeCall handler with webView")
        agentBridge.onMakeCall = { @MainActor number in
            debugLog("🔔 onMakeCall triggered with number: \(number)")
            return await self.performCall(number: number, in: webView)
        }
    }
    
    private func setupAgentBridge() {
        debugLog("setupAgentBridge called")
        
        // Note: onMakeCall is registered in setupWebView when webView is ready
        
        agentBridge.onSendSMS = { @MainActor [weak webView] number, text in
            guard let webView = webView else { return false }
            return await performSMS(number: number, text: text, in: webView)
        }
        
        agentBridge.onReload = { [weak webView] in
            if let url = URL(string: Constants.googleVoiceURL) {
                webView?.load(URLRequest(url: url))
            }
        }
        
        agentBridge.onSetTheme = { themeName in
            theme = themeName
        }
        
        agentBridge.getStatus = { [weak appState] in
            return (appState?.notificationCount ?? 0, theme)
        }
    }
    
    /// Performs a call using Google Voice's URL-based calling API
    @MainActor
    private func performCall(number: String, in webView: WKWebView) async -> Bool {
        debugLog("📞 performCall started with number: \(number)")
        
        // Clean the number - remove spaces, dashes, parentheses, and other non-digits
        let cleanNumber = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        debugLog("📞 Cleaned number: \(cleanNumber)")
        
        guard !cleanNumber.isEmpty else {
            debugLog("❌ Clean number is empty!")
            return false
        }
        
        // Add country code if not present (assume US +1)
        let fullNumber: String
        if cleanNumber.hasPrefix("1") && cleanNumber.count == 11 {
            fullNumber = cleanNumber
        } else if cleanNumber.count == 10 {
            fullNumber = "1" + cleanNumber
        } else {
            fullNumber = cleanNumber
        }
        debugLog("📞 Full number with country code: \(fullNumber)")
        
        // Google Voice URL-based calling: %2B is URL-encoded "+"
        // Format: https://voice.google.com/u/0/calls?a=nc,%2B{phonenumber}
        let callURL = "https://voice.google.com/u/0/calls?a=nc,%2B\(fullNumber)"
        debugLog("📞 Call URL: \(callURL)")
        
        guard let url = URL(string: callURL) else {
            debugLog("❌ Failed to create URL!")
            return false
        }
        
        debugLog("🚀 Loading URL in WebView...")
        webView.load(URLRequest(url: url))
        debugLog("✅ URL load request sent!")
        
        // Schedule button click after delay (fire-and-forget)
        scheduleCallButtonClick(in: webView)
        
        return true
    }
    
    /// Schedules a click on the Call button after a delay
    @MainActor
    private func scheduleCallButtonClick(in webView: WKWebView) {
        debugLog("📋 Scheduling call button click...")
        
        // Use DispatchQueue for reliable delayed execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak webView] in
            guard let webView = webView else {
                debugLog("❌ WebView was deallocated")
                return
            }
            
            debugLog("🖱️ Attempting to click Call button...")
            
            // JavaScript to find and click the Call button
            let clickScript = """
            (function() {
                // Try finding by text content first
                var buttons = document.querySelectorAll('button');
                for (var i = 0; i < buttons.length; i++) {
                    var btn = buttons[i];
                    var text = btn.textContent || btn.innerText;
                    if (text.trim() === 'Call') {
                        btn.click();
                        return 'clicked-by-text: ' + text;
                    }
                }
                
                // Try multiple selectors for the Call button
                var selectors = [
                    'button[data-action="call"]',
                    'button.call-button',
                    '[role="dialog"] button:last-child',
                    'button[jsname]'
                ];
                
                for (var j = 0; j < selectors.length; j++) {
                    try {
                        var el = document.querySelector(selectors[j]);
                        if (el) {
                            el.click();
                            return 'clicked-selector: ' + selectors[j];
                        }
                    } catch(e) {}
                }
                
                // Return info about what buttons exist
                var btnInfo = [];
                for (var k = 0; k < buttons.length; k++) {
                    btnInfo.push(buttons[k].textContent.trim().substring(0, 20));
                }
                return 'no-call-button. Found buttons: ' + btnInfo.join(', ');
            })();
            """
            
            webView.evaluateJavaScript(clickScript) { result, error in
                if let error = error {
                    debugLog("❌ Click error: \(error.localizedDescription)")
                } else {
                    debugLog("✅ Click result: \(String(describing: result))")
                }
            }
        }
    }
    
    /// Performs SMS via JavaScript injection
    @MainActor
    private func performSMS(number: String, text: String, in webView: WKWebView) async -> Bool {
        // Note: SMS automation is more complex and depends on Google Voice's current UI
        let escapedNumber = number.replacingOccurrences(of: "'", with: "\\'")
        let escapedText = text.replacingOccurrences(of: "'", with: "\\'")
        let js = """
        (function() {
            console.log('SMS automation requested for: \(escapedNumber), message: \(escapedText)');
            // TODO: Implement SMS automation based on current Google Voice UI
            return false;
        })();
        """
        
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(js) { result, error in
                if let success = result as? Bool {
                    continuation.resume(returning: success)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    /// Reloads the web view
    public func reload() {
        if let url = URL(string: Constants.googleVoiceURL) {
            webView?.load(URLRequest(url: url))
        }
    }
}

// Notification name for reload
extension Notification.Name {
    public static let reloadWebView = Notification.Name("reloadWebView")
}
