import Foundation
import FlyingFox
import os.log

private let logger = Logger(subsystem: "com.voicedesktop.app", category: "AgentBridge")

public enum AgentBridgeError: Error, LocalizedError, Sendable {
    case invalidPort(Int)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPort(let port):
            return "Invalid agent port: \(port). Expected a value between 1 and 65535."
        }
    }
}

public enum CallCommandStatus: String, Codable, Sendable {
    case queued
    case dialerOpen = "dialer_open"
    case callButtonClicked = "call_button_clicked"
    case failed
}

public struct CallCommandResult: Codable, Sendable {
    public let status: CallCommandStatus
    public let number: String
    public let message: String?
    
    public init(status: CallCommandStatus, number: String, message: String? = nil) {
        self.status = status
        self.number = number
        self.message = message
    }
}

private struct HealthResponse: Codable {
    let status: String
}

private struct StatusResponse: Codable {
    let notifications: Int
    let theme: String
    let connected: Bool
}

private struct CommandResponse: Codable {
    let status: String
    let message: String?
}

private struct ErrorResponse: Codable {
    let error: String
}

private func makeJSONResponse<T: Encodable>(statusCode: HTTPStatusCode, payload: T) -> HTTPResponse {
    let encoder = JSONEncoder()
    guard let body = try? encoder.encode(payload) else {
        return HTTPResponse(statusCode: .internalServerError, body: Data(#"{"error":"Failed to encode response"}"#.utf8))
    }
    return HTTPResponse(statusCode: statusCode, body: body)
}

/// HTTP server for agent communication using FlyingFox REST API
@Observable
@MainActor
public final class AgentBridge {
    public var isRunning: Bool = false
    public var port: Int
    
    private var server: HTTPServer?
    private var serverTask: Task<Void, any Error>?
    
    // Callbacks for handling commands
    public var onMakeCall: ((String) async -> CallCommandResult)?
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
        guard (1...65535).contains(port) else {
            throw AgentBridgeError.invalidPort(port)
        }
        
        server = HTTPServer(address: .loopback(port: UInt16(port)))
        
        // Health check endpoint
        await server?.appendRoute("GET /health") { _ in
            makeJSONResponse(statusCode: .ok, payload: HealthResponse(status: "ok"))
        }
        
        // Status endpoint (REST)
        await server?.appendRoute("GET /status") { [weak self] (_: HTTPRequest) in
            guard let self = self else {
                return HTTPResponse(statusCode: .serviceUnavailable)
            }
            
            let status = await MainActor.run {
                self.getStatus?() ?? (0, "default")
            }
            let payload = StatusResponse(notifications: status.0, theme: status.1, connected: true)
            return makeJSONResponse(statusCode: .ok, payload: payload)
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
                    let result = await withCheckedContinuation { (continuation: CheckedContinuation<CallCommandResult, Never>) in
                        Task { @MainActor in
                            guard let callback = self.onMakeCall else {
                                continuation.resume(returning: CallCommandResult(
                                    status: .failed,
                                    number: number,
                                    message: "Call handler unavailable"
                                ))
                                return
                            }
                            continuation.resume(returning: await callback(number))
                        }
                    }
                    
                    return makeJSONResponse(statusCode: .ok, payload: result)
                }
                return makeJSONResponse(statusCode: .badRequest, payload: ErrorResponse(error: "Invalid request"))
            } catch {
                return makeJSONResponse(statusCode: .badRequest, payload: ErrorResponse(error: "Invalid JSON"))
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
                    let sent = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                        Task { @MainActor in
                            guard let callback = self.onSendSMS else {
                                continuation.resume(returning: false)
                                return
                            }
                            continuation.resume(returning: await callback(number, text))
                        }
                    }
                    
                    if sent {
                        return makeJSONResponse(statusCode: .ok, payload: CommandResponse(status: "sent", message: nil))
                    } else {
                        return makeJSONResponse(
                            statusCode: .ok,
                            payload: CommandResponse(status: "failed", message: "SMS automation did not complete")
                        )
                    }
                }
                return makeJSONResponse(statusCode: .badRequest, payload: ErrorResponse(error: "Invalid request"))
            } catch {
                return makeJSONResponse(statusCode: .badRequest, payload: ErrorResponse(error: "Invalid JSON"))
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
            return makeJSONResponse(statusCode: .ok, payload: CommandResponse(status: "reloaded", message: nil))
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
                    return makeJSONResponse(
                        statusCode: .ok,
                        payload: CommandResponse(status: "theme_changed", message: nil)
                    )
                }
                return makeJSONResponse(statusCode: .badRequest, payload: ErrorResponse(error: "Invalid request"))
            } catch {
                return makeJSONResponse(statusCode: .badRequest, payload: ErrorResponse(error: "Invalid JSON"))
            }
        }
        
        isRunning = true
        logger.info("AgentBridge started on port \(self.port)")
        print("AgentBridge started on port \(port)")
        print("Endpoints available:")
        print("  GET  /health - Health check")
        print("  GET  /status - Get app status")
        print("  POST /call   - Make a call (returns queued/dialer_open/call_button_clicked/failed)")
        print("  POST /sms    - Send SMS (body: {\"number\": \"+1...\", \"text\": \"...\"})")
        print("  POST /reload - Reload the web view")
        print("  POST /theme  - Set theme (body: {\"theme\": \"dracula\"})")
        
        // Start server in background task
        serverTask = Task.detached { [server] in
            try await server?.run()
        }
    }
    
    /// Updates the listening port and restarts the server when needed.
    public func updatePort(_ newPort: Int) async throws {
        guard (1...65535).contains(newPort) else {
            throw AgentBridgeError.invalidPort(newPort)
        }
        
        guard newPort != port else { return }
        
        let shouldRestart = isRunning
        if shouldRestart {
            await stop()
        }
        
        port = newPort
        
        if shouldRestart {
            try await start()
        }
    }
    
    /// Stops the server
    public func stop() async {
        serverTask?.cancel()
        serverTask = nil
        await server?.stop()
        server = nil
        isRunning = false
        logger.info("AgentBridge stopped")
        print("AgentBridge stopped")
    }
}
