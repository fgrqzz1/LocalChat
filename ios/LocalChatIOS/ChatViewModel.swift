import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var serverAddress: String = "ws://192.168.1.10:8765/ws"
    @Published var nickname: String = ""
    @Published var inputMessage: String = ""
    @Published var messages: [ChatItem] = []
    @Published var onlineUsers: [UserInfoPayload] = []
    @Published var isConnected = false
    @Published var statusText = "Отключено"
    @Published var errorText: String?

    private let socketClient = ChatWebSocketClient()

    init() {
        socketClient.onConnected = { [weak self] in
            Task { @MainActor [weak self] in
                self?.isConnected = true
                self?.statusText = "Подключено, регистрация..."
            }
        }

        socketClient.onDisconnected = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.isConnected = false
                self?.statusText = "Отключено"
                if let error {
                    self?.errorText = error.localizedDescription
                }
            }
        }

        socketClient.onTextMessage = { [weak self] text in
            Task { @MainActor [weak self] in
                self?.consumeIncoming(text: text)
            }
        }
    }

    func connect() {
        let trimmedAddress = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAddress.isEmpty else {
            errorText = "Введите адрес сервера"
            return
        }
        guard !trimmedNickname.isEmpty else {
            errorText = "Введите ник"
            return
        }

        do {
            let normalizedEndpoint = normalizeEndpoint(trimmedAddress)
            serverAddress = normalizedEndpoint
            try socketClient.connect(to: normalizedEndpoint)
            try socketClient.send(OutgoingMessage.register(username: trimmedNickname))
            statusText = "Подключено"
            errorText = nil
        } catch {
            errorText = error.localizedDescription
            statusText = "Ошибка подключения"
        }
    }

    func disconnect() {
        socketClient.disconnect()
    }

    func sendMessage() {
        let text = inputMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        do {
            try socketClient.send(OutgoingMessage.chat(message: text))
            inputMessage = ""
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func consumeIncoming(text: String) {
        guard let data = text.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = raw["type"] as? String else {
            return
        }

        switch type {
        case "registered":
            statusText = "Подключено и зарегистрировано"
        case "error":
            if let payload = raw["payload"] as? [String: Any],
               let message = payload["message"] as? String {
                errorText = message
            } else if let message = raw["message"] as? String {
                errorText = message
            }
        case "system":
            decodeEnvelope(SystemPayload.self, from: data) { payload in
                messages.append(
                    ChatItem(
                        kind: .system,
                        title: "Система",
                        body: payload.message,
                        timestamp: Date(timeIntervalSince1970: payload.timestamp),
                        isOwn: false
                    )
                )
            }
        case "chat":
            decodeEnvelope(ChatPayload.self, from: data) { payload in
                let currentNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let incomingNickname = payload.nickname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                messages.append(
                    ChatItem(
                        kind: .chat,
                        title: payload.nickname,
                        body: payload.message,
                        timestamp: Date(timeIntervalSince1970: payload.timestamp),
                        isOwn: !currentNickname.isEmpty && currentNickname == incomingNickname
                    )
                )
            }
        case "history":
            decodeEnvelope(HistoryPayload.self, from: data) { payload in
                let currentNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                messages.append(
                    contentsOf: payload.messages.map {
                        let incomingNickname = $0.nickname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        return ChatItem(
                            kind: .chat,
                            title: $0.nickname,
                            body: $0.message,
                            timestamp: Date(timeIntervalSince1970: $0.timestamp),
                            isOwn: !currentNickname.isEmpty && currentNickname == incomingNickname
                        )
                    }
                )
            }
        case "users":
            decodeEnvelope(UsersPayload.self, from: data) { payload in
                onlineUsers = payload.users.sorted { $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending }
            }
        default:
            break
        }
    }

    private func decodeEnvelope<T: Decodable>(
        _ payloadType: T.Type,
        from data: Data,
        handler: (T) -> Void
    ) {
        let decoder = JSONDecoder()
        guard let envelope = try? decoder.decode(ServerEnvelope<T>.self, from: data),
              let payload = envelope.payload else {
            return
        }
        handler(payload)
    }

    private func normalizeEndpoint(_ input: String) -> String {
        var address = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if !address.lowercased().hasPrefix("ws://") && !address.lowercased().hasPrefix("wss://") {
            address = "ws://\(address)"
        }

        if let url = URL(string: address) {
            let path = url.path
            if path.isEmpty || path == "/" {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.path = "/ws"
                return components?.string ?? address
            }
        }

        return address
    }
}
