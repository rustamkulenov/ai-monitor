import Foundation

public enum LLMServiceStatus: String, Sendable {
    case on = "🟢"
    case off = "⚪"

    public var label: String { rawValue }
}

public protocol LLMStatusReporter {
    var name: String { get }
    var endpoint: URL { get }
    func checkStatus() async -> LLMServiceStatus
}

public enum LLMStatusProbe {
    public static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    public static func check(_ url: URL, using session: URLSession = LLMStatusProbe.session) async -> LLMServiceStatus {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return .off
            }
            return .on
        } catch {
            return .off
        }
    }
}

public struct OllamaStatusReporter: LLMStatusReporter {
    public let name = "Ollama"
    public let endpoint: URL
    private let session: URLSession

    public init(endpoint: URL = URL(string: "http://127.0.0.1:11434")!,
                session: URLSession = LLMStatusProbe.session) {
        self.endpoint = endpoint
        self.session = session
    }

    public var healthCheckURL: URL {
        endpoint.appendingPathComponent("api/tags")
    }

    public func checkStatus() async -> LLMServiceStatus {
        await LLMStatusProbe.check(healthCheckURL, using: session)
    }
}

public struct LMStudioStatusReporter: LLMStatusReporter {
    public let name = "LM Studio"
    public let endpoint: URL
    private let session: URLSession

    public init(endpoint: URL = URL(string: "http://127.0.0.1:1234")!,
                session: URLSession = LLMStatusProbe.session) {
        self.endpoint = endpoint
        self.session = session
    }

    public var healthCheckURL: URL {
        endpoint.appendingPathComponent("v1/models")
    }

    public func checkStatus() async -> LLMServiceStatus {
        await LLMStatusProbe.check(healthCheckURL, using: session)
    }
}
