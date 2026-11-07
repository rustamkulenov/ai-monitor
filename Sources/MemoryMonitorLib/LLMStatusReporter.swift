import Foundation

// MARK: - Status

/// Availability of a local LLM service.
public enum LLMServiceStatus: String, Sendable {
    case on = "On"
    case off = "Off"

    public var label: String { rawValue }
}

// MARK: - Reporter

/// A service that can report whether a local LLM server is reachable.
public protocol LLMStatusReporter {
    /// Human-readable service name, e.g. "Ollama".
    var name: String { get }
    /// Base URL of the service (the REST API root).
    var endpoint: URL { get }
    /// Performs a lightweight REST health probe and returns the current status.
    func checkStatus() async -> LLMServiceStatus
}

// MARK: - Shared probe

public enum LLMStatusProbe {
    /// Default short-timeout session used for localhost health checks.
    /// A dedicated session avoids inheriting app-wide timeouts or waiting for connectivity.
    public static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    /// Returns `.on` when `url` answers with a 2xx HTTP status, `.off` otherwise.
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

// MARK: - Ollama

/// Reports whether a local Ollama server is running.
/// Health endpoint: `GET http://localhost:11434/api/tags`
public struct OllamaStatusReporter: LLMStatusReporter {
    public let name = "Ollama"
    public let endpoint: URL
    private let session: URLSession

    public init(endpoint: URL = URL(string: "http://127.0.0.1:11434")!,
                session: URLSession = LLMStatusProbe.session) {
        self.endpoint = endpoint
        self.session = session
    }

    /// REST endpoint used for the health check.
    public var healthCheckURL: URL {
        endpoint.appendingPathComponent("api/tags")
    }

    public func checkStatus() async -> LLMServiceStatus {
        await LLMStatusProbe.check(healthCheckURL, using: session)
    }
}

// MARK: - LM Studio

/// Reports whether a local LM Studio server is running.
/// Health endpoint: `GET http://localhost:1234/v1/models`
public struct LMStudioStatusReporter: LLMStatusReporter {
    public let name = "LM Studio"
    public let endpoint: URL
    private let session: URLSession

    public init(endpoint: URL = URL(string: "http://127.0.0.1:1234")!,
                session: URLSession = LLMStatusProbe.session) {
        self.endpoint = endpoint
        self.session = session
    }

    /// REST endpoint used for the health check.
    public var healthCheckURL: URL {
        endpoint.appendingPathComponent("v1/models")
    }

    public func checkStatus() async -> LLMServiceStatus {
        await LLMStatusProbe.check(healthCheckURL, using: session)
    }
}
