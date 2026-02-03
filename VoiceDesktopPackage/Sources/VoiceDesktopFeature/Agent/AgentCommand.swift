import Foundation

/// Commands that can be sent from an agent to the app via WebSocket
public enum AgentCommand: Codable, Sendable {
    case makeCall(number: String)
    case sendSMS(number: String, text: String)
    case getStatus
    case getNotifications
    case setTheme(theme: String)
    case reload
    
    private enum CodingKeys: String, CodingKey {
        case type
        case number
        case text
        case theme
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "makeCall":
            let number = try container.decode(String.self, forKey: .number)
            self = .makeCall(number: number)
        case "sendSMS":
            let number = try container.decode(String.self, forKey: .number)
            let text = try container.decode(String.self, forKey: .text)
            self = .sendSMS(number: number, text: text)
        case "getStatus":
            self = .getStatus
        case "getNotifications":
            self = .getNotifications
        case "setTheme":
            let theme = try container.decode(String.self, forKey: .theme)
            self = .setTheme(theme: theme)
        case "reload":
            self = .reload
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [CodingKeys.type],
                    debugDescription: "Unknown command type: \(type)"
                )
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .makeCall(let number):
            try container.encode("makeCall", forKey: .type)
            try container.encode(number, forKey: .number)
        case .sendSMS(let number, let text):
            try container.encode("sendSMS", forKey: .type)
            try container.encode(number, forKey: .number)
            try container.encode(text, forKey: .text)
        case .getStatus:
            try container.encode("getStatus", forKey: .type)
        case .getNotifications:
            try container.encode("getNotifications", forKey: .type)
        case .setTheme(let theme):
            try container.encode("setTheme", forKey: .type)
            try container.encode(theme, forKey: .theme)
        case .reload:
            try container.encode("reload", forKey: .type)
        }
    }
}
