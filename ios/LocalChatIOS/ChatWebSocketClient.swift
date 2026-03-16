import Foundation

final class ChatWebSocketClient {
    enum ClientError: Error, LocalizedError {
        case badURL
        case disconnected
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .badURL:
                return "Некорректный URL WebSocket"
            case .disconnected:
                return "Нет подключения к серверу"
            case .encodingFailed:
                return "Не удалось подготовить сообщение"
            }
        }
    }

    var onTextMessage: ((String) -> Void)?
    var onConnected: (() -> Void)?
    var onDisconnected: ((Error?) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isConnected = false

    func connect(to endpoint: String) throws {
        guard let url = URL(string: endpoint) else {
            throw ClientError.badURL
        }

        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        session = URLSession(configuration: cfg)
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        onConnected?()

        receiveLoop()
    }

    func disconnect() {
        isConnected = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        onDisconnected?(nil)
    }

    func send<T: Encodable>(_ payload: T) throws {
        guard isConnected, let webSocketTask else {
            throw ClientError.disconnected
        }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(payload),
              let text = String(data: data, encoding: .utf8) else {
            throw ClientError.encodingFailed
        }

        webSocketTask.send(.string(text)) { [weak self] error in
            if let error {
                self?.onDisconnected?(error)
            }
        }
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.onTextMessage?(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.onTextMessage?(text)
                    }
                @unknown default:
                    break
                }

                self.receiveLoop()
            case .failure(let error):
                self.isConnected = false
                self.onDisconnected?(error)
            }
        }
    }
}
