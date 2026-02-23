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
    
    private struct CallClickAttemptResult {
        let clicked: Bool
        let detail: String
    }
    
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
    private func performCall(number: String, in webView: WKWebView) async -> CallCommandResult {
        debugLog("📞 performCall started with number: \(number)")
        
        // Clean the number - remove spaces, dashes, parentheses, and other non-digits
        let cleanNumber = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        debugLog("📞 Cleaned number: \(cleanNumber)")
        
        guard !cleanNumber.isEmpty else {
            debugLog("❌ Clean number is empty!")
            return CallCommandResult(
                status: .failed,
                number: number,
                message: "No digits found in number"
            )
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
            return CallCommandResult(
                status: .failed,
                number: fullNumber,
                message: "Invalid call URL"
            )
        }
        
        debugLog("🚀 Loading URL in WebView...")
        webView.load(URLRequest(url: url))
        debugLog("✅ URL load request sent!")
        
        let dialerReady = await waitForDialerReady(in: webView)
        guard dialerReady else {
            debugLog("⏳ Dialer UI still loading after timeout, leaving request queued")
            return CallCommandResult(
                status: .queued,
                number: fullNumber,
                message: "Call UI still loading"
            )
        }
        
        debugLog("📲 Dialer ready, attempting call button click with retries")
        let clickResult = await clickCallButtonWithRetry(in: webView)
        if clickResult.clicked {
            debugLog("✅ Call button clicked: \(clickResult.detail)")
            return CallCommandResult(
                status: .callButtonClicked,
                number: fullNumber,
                message: clickResult.detail
            )
        }
        
        debugLog("⚠️ Dialer opened but call button was not clicked: \(clickResult.detail)")
        return CallCommandResult(
            status: .dialerOpen,
            number: fullNumber,
            message: clickResult.detail
        )
    }
    
    /// Waits for the call UI to become ready before clicking
    @MainActor
    private func waitForDialerReady(
        in webView: WKWebView,
        timeout: TimeInterval = 10.0,
        pollInterval: TimeInterval = 0.4
    ) async -> Bool {
        let readyScript = """
        (function() {
            const href = window.location.href || '';
            const ready = document.readyState === 'complete' || document.readyState === 'interactive';
            const inCallsView = href.indexOf('/calls') >= 0;
            const controls = Array.from(document.querySelectorAll('button,[role="button"]'));
            const hasCallControls = controls.some((el) => {
                const text = ((el.textContent || el.getAttribute('aria-label') || '') + '').trim().toLowerCase();
                return text.indexOf('call') >= 0 || text.indexOf('dial') >= 0;
            });
            return !!(ready && inCallsView && hasCallControls);
        })();
        """
        
        let maxAttempts = max(1, Int(timeout / pollInterval))
        for attempt in 1...maxAttempts {
            if let isReady = await evaluateJavaScriptBoolean(readyScript, in: webView), isReady {
                debugLog("✅ Dialer ready after \(attempt) attempt(s)")
                return true
            }
            
            let sleepNanos = UInt64(max(0.1, pollInterval) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: sleepNanos)
        }
        
        return false
    }
    
    /// Retries clicking call controls to handle slow UI transitions
    @MainActor
    private func clickCallButtonWithRetry(
        in webView: WKWebView,
        maxAttempts: Int = 8,
        pollInterval: TimeInterval = 0.5
    ) async -> CallClickAttemptResult {
        let clickScript = """
        (function() {
            const visible = (el) => !!(el && (el.offsetWidth || el.offsetHeight || el.getClientRects().length));
            const controls = Array.from(document.querySelectorAll('button,[role="button"]'));
            const keywords = ['call', 'place call', 'start call', 'dial'];
            
            for (const el of controls) {
                const text = ((el.textContent || el.getAttribute('aria-label') || '') + '').trim().toLowerCase();
                if (!text || el.disabled || !visible(el)) {
                    continue;
                }
                if (keywords.some((keyword) => text === keyword || text.indexOf(keyword) >= 0)) {
                    el.click();
                    return 'clicked:text:' + text;
                }
            }
            
            const selectors = [
                'button[data-action=\"call\"]',
                '[role=\"dialog\"] button:last-child',
                'button[jsname]'
            ];
            
            for (const selector of selectors) {
                const el = document.querySelector(selector);
                if (el && !el.disabled && visible(el)) {
                    el.click();
                    return 'clicked:selector:' + selector;
                }
            }
            
            const sample = controls
                .map((el) => ((el.textContent || el.getAttribute('aria-label') || '') + '').trim().toLowerCase())
                .filter((text) => text.length > 0)
                .slice(0, 8)
                .join('|');
            return 'not-found:' + sample;
        })();
        """
        
        var lastDetail = "Call button not found"
        for attempt in 1...max(1, maxAttempts) {
            if let clickResult = await evaluateJavaScriptString(clickScript, in: webView) {
                if clickResult.hasPrefix("clicked:") {
                    return CallClickAttemptResult(clicked: true, detail: clickResult)
                }
                
                lastDetail = clickResult
                debugLog("ℹ️ Call click attempt \(attempt) did not click: \(clickResult)")
            }
            
            let sleepNanos = UInt64(max(0.1, pollInterval) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: sleepNanos)
        }
        
        return CallClickAttemptResult(clicked: false, detail: lastDetail)
    }
    
    /// Executes JavaScript and returns a Bool value for polling checks
    @MainActor
    private func evaluateJavaScriptBoolean(_ script: String, in webView: WKWebView) async -> Bool? {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    debugLog("❌ JavaScript evaluation error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: result as? Bool)
            }
        }
    }
    
    /// Executes JavaScript and returns a String value for click diagnostics
    @MainActor
    private func evaluateJavaScriptString(_ script: String, in webView: WKWebView) async -> String? {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    debugLog("❌ JavaScript evaluation error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: result as? String)
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
