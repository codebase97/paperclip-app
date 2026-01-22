import Foundation

/// Service for interacting with Paperclip API
class PaperclipService {
    static let shared = PaperclipService()

    private let baseURL = URL(string: "https://paperclip.airbase.cc/api/v1")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    // MARK: - API Methods

    /// Push content onto the stack
    func push(content: String, type: String = "text", mimeType: String = "text/plain") async throws -> PushResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("push"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = PushRequest(content: content, type: type, mime_type: mimeType)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PaperclipError.requestFailed
        }

        return try JSONDecoder().decode(PushResponse.self, from: data)
    }

    /// Peek at the latest item (no removal)
    func peek() async throws -> StackItem {
        var request = URLRequest(url: baseURL.appendingPathComponent("peek"))
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaperclipError.requestFailed
        }

        if httpResponse.statusCode == 404 {
            throw PaperclipError.stackEmpty
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw PaperclipError.requestFailed
        }

        return try JSONDecoder().decode(StackItem.self, from: data)
    }

    /// Pop the latest item (removes from stack)
    func pop() async throws -> StackItem {
        var request = URLRequest(url: baseURL.appendingPathComponent("pop"))
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaperclipError.requestFailed
        }

        if httpResponse.statusCode == 404 {
            throw PaperclipError.stackEmpty
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw PaperclipError.requestFailed
        }

        return try JSONDecoder().decode(StackItem.self, from: data)
    }

    /// Get stack history
    func getStack(limit: Int = 20) async throws -> StackResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("stack"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PaperclipError.requestFailed
        }

        return try JSONDecoder().decode(StackResponse.self, from: data)
    }
}

// MARK: - Models

struct StackItem: Codable, Identifiable {
    let id: String
    let content: String
    let type: String
    let mime_type: String
    let metadata: StackItemMetadata?
    let created_at: String

    var preview: String {
        if content.count > 60 {
            return String(content.prefix(60)) + "..."
        }
        return content
    }

    var relativeTime: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: created_at) else { return "" }

        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

struct StackItemMetadata: Codable {
    let source: String?
    let mode: String?
    let duration_ms: Int?
    let device_id: String?
    let device_name: String?
}

struct PushRequest: Codable {
    let content: String
    let type: String
    let mime_type: String
}

struct PushResponse: Codable {
    let id: String
    let created_at: String
    let stack_size: Int
}

struct StackResponse: Codable {
    let items: [StackItem]
    let total: Int
    let limit: Int
}

enum PaperclipError: LocalizedError {
    case requestFailed
    case stackEmpty

    var errorDescription: String? {
        switch self {
        case .requestFailed: return "Request failed"
        case .stackEmpty: return "Stack is empty"
        }
    }
}
