import Foundation
import FlyingFox
import os.log

private let logger = Logger(subsystem: "com.voicedesktop.app", category: "AgentBridge")

/// HTTP server for agent communication using FlyingFox REST API
@Observable
@MainActor
public final class AgentBridge {
    public var isRunning: Bool = false
    public var port: Int
    
    private var server: HTTPServer?
    private var serverTask: Task<Void, any Error>?
    
    // Callbacks for handling commands
    public var onMakeCall: ((String) async -> Bool)?
    public var onSendSMS: ((String, String) async -> Bool)?
    public var onReload: (() -> Void)?
    public var onSetTheme: ((String) -> Void)?
    public var getStatus: (() -> (Int, String))?
    
    public init(port: Int = 3000) {
        self.port = port
    }
    
    /// Starts the HTTP server
    public func start() async throws {
        guard !isRunning else { return }
        
        server = HTTPServer(address: .loopback(port: UInt16(port)))
        
        // Health check endpoint
        await server?.appendRoute("GET /health") { _ in
            HTTPResponse(statusCode: .ok, body: Data(#"{"status":"ok"}"#.utf8))
        }
        
        // Status endpoint (REST)
        await server?.appendRoute("GET /status") { [weak self] (_: HTTPRequest) in
            guard let self = self else {
                return HTTPResponse(statusCode: .serviceUnavailable)
            }
            
            let status = await MainActor.run {
                self.getStatus?() ?? (0, "default")
            }
            let json = """
            {"notifications":\(status.0),"theme":"\(status.1)","connected":true}
            """
            return HTTPResponse(statusCode: .ok, body: Data(json.utf8))
        }
        
        // Make call endpoint (REST)
        await server?.appendRoute("POST /call") { [weak self] (request: HTTPRequest) in
            guard let self = self else {
                return HTTPResponse(statusCode: .serviceUnavailable)
            }
            
            do {
                let bodyData = try await request.bodyData
                
                if let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                   let number = json["number"] as? String {
                    
                    // Execute callback on main actor using Task
                    let success = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                        Task { @MainActor in
                            guard let callback = self.onMakeCall else {
                                continuation.resume(returning: false)
                                return
                            }
                            let result = await callback(number)
                            continuation.resume(returning: result)
                        }
                    }
                    
                    if success {
                        return HTTPResponse(statusCode: .ok, body: Data(#"{"status":"initiated"}"#.utf8))
                    } else {
                        return HTTPResponse(statusCode: .ok, body: Data(#"{"status":"failed"}"#.utf8))
                    }
                }
                return HTTPResponse(statusCode: .badRequest, body: Data(#"{"error":"Invalid request"}"#.utf8))
            } catch {
                return HTTPResponse(statusCode: .badRequest, body: Data(#"{"error":"Invalid JSON"}"#.utf8))
            }
        }
        
        // Send SMS endpoint (REST)
        await server?.appendRoute("POST /sms") { [weak self] (request: HTTPRequest) in
            guard let self = self else {
                return HTTPResponse(statusCode: .serviceUnavailable)
            }
            
            do {
                let bodyData = try await request.bodyData
                if let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                   let number = json["number"] as? String,
                   let text = json["text"] as? String {
                    await MainActor.run {
                        Task {
                            _ = await self.onSendSMS?(number, text)
                        }
                    }
                    return HTTPResponse(statusCode: .ok, body: Data(#"{"status":"sent"}"#.utf8))
                }
                return HTTPResponse(statusCode: .badRequest, body: Data(#"{"error":"Invalid request"}"#.utf8))
            } catch {
                return HTTPResponse(statusCode: .badRequest, body: Data(#"{"error":"Invalid JSON"}"#.utf8))
            }
        }
        
        // Reload endpoint (REST)
        await server?.appendRoute("POST /reload") { [weak self] (_: HTTPRequest) in
            guard let self = self else {
                return HTTPResponse(statusCode: .serviceUnavailable)
            }
            
            await MainActor.run {
                self.onReload?()
            }
            return HTTPResponse(statusCode: .ok, body: Data(#"{"status":"reloaded"}"#.utf8))
        }
        
        // Set theme endpoint (REST)
        await server?.appendRoute("POST /theme") { [weak self] (request: HTTPRequest) in
            guard let self = self else {
                return HTTPResponse(statusCode: .serviceUnavailable)
            }
            
            do {
                let bodyData = try await request.bodyData
                if let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                   let theme = json["theme"] as? String {
                    await MainActor.run {
                        self.onSetTheme?(theme)
                    }
                    return HTTPResponse(statusCode: .ok, body: Data(#"{"status":"theme_changed"}"#.utf8))
                }
                return HTTPResponse(statusCode: .badRequest, body: Data(#"{"error":"Invalid request"}"#.utf8))
            } catch {
                return HTTPResponse(statusCode: .badRequest, body: Data(#"{"error":"Invalid JSON"}"#.utf8))
            }
        }
        
        isRunning = true
        print("AgentBridge started on port \(port)")
        print("Endpoints available:")
        print("  GET  /health - Health check")
        print("  GET  /status - Get app status")
        print("  POST /call   - Make a call (body: {\"number\": \"+1...\"})")
        print("  POST /sms    - Send SMS (body: {\"number\": \"+1...\", \"text\": \"...\"})")
        print("  POST /reload - Reload the web view")
        print("  POST /theme  - Set theme (body: {\"theme\": \"dracula\"})")
        
        // Start server in background task
        serverTask = Task.detached { [server] in
            try await server?.run()
        }
    }
    
    /// Stops the server
    public func stop() async {
        serverTask?.cancel()
        serverTask = nil
        await server?.stop()
        server = nil
        isRunning = false
        print("AgentBridge stopped")
    }
}
