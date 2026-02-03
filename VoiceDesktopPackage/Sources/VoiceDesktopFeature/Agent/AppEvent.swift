import Foundation

/// Events that can be sent from the app to an agent via WebSocket
public enum AppEvent: Codable, Sendable {
    case connected
    case callInitiated(number: String)
    case callEnded(number: String, duration: Int?)
    case smsSent(number: String)
    case incomingCall(number: String)
    case messageReceived(from: String, preview: String?)
    case notificationCountChanged(count: Int)
    case status(notifications: Int, theme: String, connected: Bool)
    case themeChanged(theme: String)
    case error(message: String)
    case acknowledgment(command: String, success: Bool, message: String?)
    
    private enum CodingKeys: String, CodingKey {
        case type
        case number
        case duration
        case from
        case preview
        case count
        case notifications
        case theme
        case connected
        case message
        case command
        case success
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "connected":
            self = .connected
        case "callInitiated":
            let number = try container.decode(String.self, forKey: .number)
            self = .callInitiated(number: number)
        case "callEnded":
            let number = try container.decode(String.self, forKey: .number)
            let duration = try container.decodeIfPresent(Int.self, forKey: .duration)
            self = .callEnded(number: number, duration: duration)
        case "smsSent":
            let number = try container.decode(String.self, forKey: .number)
            self = .smsSent(number: number)
        case "incomingCall":
            let number = try container.decode(String.self, forKey: .number)
            self = .incomingCall(number: number)
        case "messageReceived":
            let from = try container.decode(String.self, forKey: .from)
            let preview = try container.decodeIfPresent(String.self, forKey: .preview)
            self = .messageReceived(from: from, preview: preview)
        case "notificationCountChanged":
            let count = try container.decode(Int.self, forKey: .count)
            self = .notificationCountChanged(count: count)
        case "status":
            let notifications = try container.decode(Int.self, forKey: .notifications)
            let theme = try container.decode(String.self, forKey: .theme)
            let connected = try container.decode(Bool.self, forKey: .connected)
            self = .status(notifications: notifications, theme: theme, connected: connected)
        case "themeChanged":
            let theme = try container.decode(String.self, forKey: .theme)
            self = .themeChanged(theme: theme)
        case "error":
            let message = try container.decode(String.self, forKey: .message)
            self = .error(message: message)
        case "acknowledgment":
            let command = try container.decode(String.self, forKey: .command)
            let success = try container.decode(Bool.self, forKey: .success)
            let message = try container.decodeIfPresent(String.self, forKey: .message)
            self = .acknowledgment(command: command, success: success, message: message)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [CodingKeys.type],
                    debugDescription: "Unknown event type: \(type)"
                )
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .connected:
            try container.encode("connected", forKey: .type)
        case .callInitiated(let number):
            try container.encode("callInitiated", forKey: .type)
            try container.encode(number, forKey: .number)
        case .callEnded(let number, let duration):
            try container.encode("callEnded", forKey: .type)
            try container.encode(number, forKey: .number)
            try container.encodeIfPresent(duration, forKey: .duration)
        case .smsSent(let number):
            try container.encode("smsSent", forKey: .type)
            try container.encode(number, forKey: .number)
        case .incomingCall(let number):
            try container.encode("incomingCall", forKey: .type)
            try container.encode(number, forKey: .number)
        case .messageReceived(let from, let preview):
            try container.encode("messageReceived", forKey: .type)
            try container.encode(from, forKey: .from)
            try container.encodeIfPresent(preview, forKey: .preview)
        case .notificationCountChanged(let count):
            try container.encode("notificationCountChanged", forKey: .type)
            try container.encode(count, forKey: .count)
        case .status(let notifications, let theme, let connected):
            try container.encode("status", forKey: .type)
            try container.encode(notifications, forKey: .notifications)
            try container.encode(theme, forKey: .theme)
            try container.encode(connected, forKey: .connected)
        case .themeChanged(let theme):
            try container.encode("themeChanged", forKey: .type)
            try container.encode(theme, forKey: .theme)
        case .error(let message):
            try container.encode("error", forKey: .type)
            try container.encode(message, forKey: .message)
        case .acknowledgment(let command, let success, let message):
            try container.encode("acknowledgment", forKey: .type)
            try container.encode(command, forKey: .command)
            try container.encode(success, forKey: .success)
            try container.encodeIfPresent(message, forKey: .message)
        }
    }
}
