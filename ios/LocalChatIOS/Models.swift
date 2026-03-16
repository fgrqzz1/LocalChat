import Foundation

struct ServerEnvelope<T: Decodable>: Decodable {
    let type: String
    let payload: T?
}

struct ChatPayload: Codable, Identifiable {
    let user_id: String
    let nickname: String
    let message: String
    let timestamp: TimeInterval

    var id: String {
        "\(user_id)-\(timestamp)-\(message)"
    }
}

struct SystemPayload: Codable {
    let message: String
    let timestamp: TimeInterval
}

struct UserInfoPayload: Codable, Identifiable {
    let user_id: String
    let nickname: String

    var id: String { user_id }
}

struct UsersPayload: Codable {
    let users: [UserInfoPayload]
}

struct HistoryPayload: Codable {
    let messages: [ChatPayload]
}

struct OutgoingMessage: Encodable {
    let type: String
    let payload: [String: String]?
    let username: String?

    static func register(username: String) -> OutgoingMessage {
        OutgoingMessage(type: "register", payload: nil, username: username)
    }

    static func chat(message: String) -> OutgoingMessage {
        OutgoingMessage(
            type: "chat",
            payload: ["message": message],
            username: nil
        )
    }
}

struct ChatItem: Identifiable {
    enum Kind {
        case system
        case chat
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let body: String
    let timestamp: Date
    let isOwn: Bool
}
