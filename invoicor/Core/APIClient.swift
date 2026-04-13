// =================================================================
// FILE: Core/APIClient.swift
// =================================================================
// Single HTTP client for all API communication.
//
// PRODUCTION NOTES:
// - Tokens stored in Keychain (not UserDefaults) for security.
// - Token refresh serialized via an actor to prevent duplicate refreshes.
// - All requests have explicit timeouts.
// - Debug logging in DEBUG builds only.
// - No force unwraps anywhere.

import Foundation

// MARK: - API Error

/// Typed errors for every failure mode the API can produce.
/// Conform to `LocalizedError` so `.localizedDescription` works in UI.
enum APIError: LocalizedError, Sendable {
    case unauthorized
    case limitReached(String)
    case locked(String)
    case badRequest(String)
    case validationError([String: [String]])
    case notFound
    case networkError(String)
    case serverError
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:              return "Session expired. Please log in again."
        case .limitReached(let msg):     return msg
        case .locked(let msg):           return msg
        case .badRequest(let msg):       return msg
        case .validationError(let errs): return errs.values.flatMap { $0 }.joined(separator: "\n")
        case .notFound:                  return "Not found."
        case .networkError(let msg):     return msg
        case .serverError:               return "Server error. Try again later."
        case .decodingError(let msg):    return "Data error: \(msg)"
        }
    }
}

// MARK: - Token Storage (Keychain)

/// Secure token persistence using the iOS Keychain.
/// Never stores auth tokens in UserDefaults (plain text on disk).
enum TokenStorage {
    private static let service = "com.invoicor.tokens"

    static var accessToken: String? {
        get { read(account: "access_token") }
        set {
            if let value = newValue {
                save(account: "access_token", value: value)
            } else {
                delete(account: "access_token")
            }
        }
    }

    static var refreshToken: String? {
        get { read(account: "refresh_token") }
        set {
            if let value = newValue {
                save(account: "refresh_token", value: value)
            } else {
                delete(account: "refresh_token")
            }
        }
    }

    static var hasToken: Bool { accessToken != nil }

    static func clear() {
        delete(account: "access_token")
        delete(account: "refresh_token")
    }

    // MARK: Keychain Helpers

    private static func save(account: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        // Delete existing before saving (Keychain errors on duplicate)
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Token Refresh Actor

/// Serializes token refresh to prevent multiple concurrent refreshes.
/// If a refresh is already in flight, subsequent callers await the same result.
private actor TokenRefresher {
    private var refreshTask: Task<Bool, Never>?

    func refresh(using performer: @Sendable @escaping () async -> Bool) async -> Bool {
        // If a refresh is already in progress, piggyback on it
        if let existing = refreshTask {
            return await existing.value
        }

        let task = Task<Bool, Never> {
            let success = await performer()
            return success
        }
        refreshTask = task
        let result = await task.value
        refreshTask = nil
        return result
    }
}

// MARK: - API Client

/// Singleton HTTP client for all Invoicor API calls.
///
/// Usage:
/// ```swift
/// let me = try await APIClient.shared.request(
///     MeResponse.self, method: "GET", path: "/accounts/me/"
/// )
/// ```
final class APIClient: Sendable {
    static let shared = APIClient()
    private init() {}

    private let baseURL = AppConfig.apiBaseURL
    private let tokenRefresher = TokenRefresher()

    /// Shared URL session with production timeouts.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.requestTimeout
        config.timeoutIntervalForResource = AppConfig.resourceTimeout
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    /// JSON decoder configured for Django REST Framework responses.
    /// Converts snake_case keys to camelCase automatically.
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Public: JSON Request

    /// Standard API call. Pass the expected response type as first argument.
    ///
    /// - Parameters:
    ///   - type: The `Decodable` type to decode the response into.
    ///   - method: HTTP method (GET, POST, PUT, PATCH, DELETE).
    ///   - path: API path appended to `baseURL` (e.g. "/accounts/me/").
    ///   - body: Optional JSON body as a dictionary.
    ///   - auth: Whether to include the Bearer token. Default `true`.
    /// - Returns: Decoded response of type `T`.
    func request<T: Decodable>(
        _ type: T.Type,
        method: String,
        path: String,
        body: [String: Any]? = nil,
        auth: Bool = true
    ) async throws -> T {
        var (data, http) = try await perform(method: method, path: path, body: body, auth: auth)

        if http.statusCode == 401 && auth {
            if await refreshTokensSerialized() {
                (data, http) = try await perform(method: method, path: path, body: body, auth: auth)
            } else {
                throw APIError.unauthorized
            }
        }

        return try decode(type, data: data, http: http)
    }

    // MARK: - Public: Raw Text (HTML/SVG endpoints)

    /// For endpoints that return raw text (HTML, SVG), not JSON.
    func requestRaw(
        method: String = "GET",
        path: String,
        auth: Bool = true
    ) async throws -> String {
        var (data, http) = try await perform(method: method, path: path, auth: auth)

        if http.statusCode == 401 && auth {
            if await refreshTokensSerialized() {
                (data, http) = try await perform(method: method, path: path, auth: auth)
            } else {
                throw APIError.unauthorized
            }
        }

        if (200...299).contains(http.statusCode) {
            return String(data: data, encoding: .utf8) ?? ""
        }
        if http.statusCode == 404 { throw APIError.notFound }
        throw APIError.serverError
    }

    // MARK: - Public: No Content (DELETE, void POST)

    /// For endpoints that return no body (204) or where the response is irrelevant.
    func requestNoContent(
        method: String,
        path: String,
        body: [String: Any]? = nil,
        auth: Bool = true
    ) async throws {
        var (data, http) = try await perform(method: method, path: path, body: body, auth: auth)

        if http.statusCode == 401 && auth {
            if await refreshTokensSerialized() {
                (data, http) = try await perform(method: method, path: path, body: body, auth: auth)
            } else {
                throw APIError.unauthorized
            }
        }

        if (200...299).contains(http.statusCode) { return }
        try throwHTTPError(data: data, http: http)
    }

    // MARK: - Public: Multipart Upload

    /// Upload an image (logo) with optional additional form fields.
    func upload<T: Decodable>(
        _ type: T.Type,
        method: String = "PUT",
        path: String,
        image: Data,
        fieldName: String = "logo",
        additionalFields: [String: String] = [:]
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"

        var (data, http) = try await performUpload(
            method: method, path: path, image: image,
            fieldName: fieldName, boundary: boundary,
            additionalFields: additionalFields
        )

        if http.statusCode == 401 {
            if await refreshTokensSerialized() {
                (data, http) = try await performUpload(
                    method: method, path: path, image: image,
                    fieldName: fieldName, boundary: boundary,
                    additionalFields: additionalFields
                )
            } else {
                throw APIError.unauthorized
            }
        }

        return try decode(type, data: data, http: http)
    }

    // MARK: - Private: Raw HTTP

    private func perform(
        method: String,
        path: String,
        body: [String: Any]? = nil,
        auth: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.badRequest("Invalid URL: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if auth, let token = TokenStorage.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        Self.logRequest(request, body: body)

        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch let urlError as URLError {
            throw APIError.networkError(Self.friendlyMessage(for: urlError))
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }

        guard let http = result.1 as? HTTPURLResponse else {
            throw APIError.serverError
        }

        Self.logResponse(http, data: result.0, for: request)
        return (result.0, http)
    }

    // MARK: - Private: Multipart Upload

    private func performUpload(
        method: String,
        path: String,
        image: Data,
        fieldName: String,
        boundary: String,
        additionalFields: [String: String]
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.badRequest("Invalid URL: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = TokenStorage.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()

        // Additional text fields
        for (key, value) in additionalFields {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendString("\(value)\r\n")
        }

        // Image file field
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"logo.jpg\"\r\n")
        body.appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(image)
        body.appendString("\r\n--\(boundary)--\r\n")

        let (data, response) = try await session.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse else { throw APIError.serverError }
        return (data, http)
    }

    // MARK: - Private: Decode

    private func decode<T: Decodable>(_ type: T.Type, data: Data, http: HTTPURLResponse) throws -> T {
        if (200...299).contains(http.statusCode) {
            do {
                return try decoder.decode(type, from: data)
            } catch let decodingError {
                #if DEBUG
                print("⚠️ [API] Decoding \(type) failed: \(decodingError)")
                if let raw = String(data: data, encoding: .utf8) {
                    print("⚠️ [API] Raw response: \(raw.prefix(500))")
                }
                #endif
                throw APIError.decodingError(decodingError.localizedDescription)
            }
        }
        try throwHTTPError(data: data, http: http)
    }

    // MARK: - Private: Error Mapping

    private func throwHTTPError(data: Data, http: HTTPURLResponse) throws -> Never {
        // Try standard error format first
        let standardError = try? decoder.decode(APIErrorResponse.self, from: data)

        // Try DRF validation error format: {"field": ["error1", "error2"]}
        if http.statusCode == 400, standardError?.error == nil {
            if let validationErrors = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] {
                throw APIError.validationError(validationErrors)
            }
        }

        let msg = standardError?.error ?? "Unknown error"

        switch http.statusCode {
        case 400:  throw APIError.badRequest(msg)
        case 401:  throw APIError.unauthorized
        case 403:
            if standardError?.code == "LIMIT_REACHED" { throw APIError.limitReached(msg) }
            if standardError?.code == "LOCKED"        { throw APIError.locked(msg) }
            throw APIError.badRequest(msg)
        case 404:  throw APIError.notFound
        case 429:  throw APIError.badRequest("Too many requests. Please wait a moment.")
        default:   throw APIError.serverError
        }
    }

    // MARK: - Private: Token Refresh (Serialized)

    /// Refreshes the access token, serialized so concurrent 401s only trigger one refresh.
    private func refreshTokensSerialized() async -> Bool {
        await tokenRefresher.refresh { [self] in
            await self.performTokenRefresh()
        }
    }

    private func performTokenRefresh() async -> Bool {
        guard let refresh = TokenStorage.refreshToken else { return false }
        do {
            let (data, http) = try await perform(
                method: "POST",
                path: "/accounts/token/refresh/",
                body: ["refresh": refresh],
                auth: false
            )
            guard http.statusCode == 200 else {
                #if DEBUG
                print("⚠️ [API] Token refresh failed with status \(http.statusCode)")
                #endif
                return false
            }
            let tokens = try decoder.decode(LoginResponse.self, from: data)
            TokenStorage.accessToken = tokens.access
            TokenStorage.refreshToken = tokens.refresh
            #if DEBUG
            print("✅ [API] Token refreshed successfully")
            #endif
            return true
        } catch {
            #if DEBUG
            print("⚠️ [API] Token refresh error: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Private: Debug Logging

    private static func logRequest(_ request: URLRequest, body: [String: Any]?) {
        #if DEBUG
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "?"
        print("➡️ [API] \(method) \(url)")
        if let body {
            // Redact sensitive fields
            var safeBody = body
            for key in ["password", "refresh", "access"] {
                if safeBody[key] != nil { safeBody[key] = "***" }
            }
            print("   Body: \(safeBody)")
        }
        #endif
    }

    private static func logResponse(_ http: HTTPURLResponse, data: Data, for request: URLRequest) {
        #if DEBUG
        let method = request.httpMethod ?? "?"
        let path = request.url?.path ?? "?"
        let emoji = (200...299).contains(http.statusCode) ? "✅" : "❌"
        print("\(emoji) [API] \(method) \(path) → \(http.statusCode) (\(data.count) bytes)")
        #endif
    }

    /// User-friendly messages for common network errors.
    private static func friendlyMessage(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet: return "No internet connection."
        case .timedOut:               return "Request timed out. Please try again."
        case .cannotFindHost:         return "Cannot reach server. Check your connection."
        case .networkConnectionLost:  return "Connection lost. Please try again."
        default:                      return "Network error. Please try again."
        }
    }
}

// MARK: - Data Extension (Multipart Helper)

private extension Data {
    /// Safely append a string as UTF-8 data. No force unwrap.
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
