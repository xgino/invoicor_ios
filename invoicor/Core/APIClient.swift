// =================================================================
// FILE: Core/APIClient.swift — REPLACE ENTIRELY
// =================================================================
// FIX: request() now takes the type as first parameter:
//   request(LoginResponse.self, method: "POST", ...)
// instead of relying on return-type inference:
//   let x: LoginResponse = request(method: "POST", ...)
//
// This matches how JSONDecoder works: decode(Type.self, from: data)
// Swift can always infer T when you pass Type.self explicitly.
import Foundation
// MARK: - Error Types
enum APIError: LocalizedError {
case unauthorized
case limitReached(String)
case locked(String)
case badRequest(String)
case notFound
case networkError
case serverError
case decodingError(String)
var errorDescription: String? {
    switch self {
    case .unauthorized: return "Session expired. Please log in again."
    case .limitReached(let msg): return msg
    case .locked(let msg): return msg
    case .badRequest(let msg): return msg
    case .notFound: return "Not found."
    case .networkError: return "No internet connection."
    case .serverError: return "Server error. Try again later."
    case .decodingError(let msg): return "Data error: \(msg)"
    }
}
}
// MARK: - Token Storage
enum TokenStorage {
private static let defaults = UserDefaults.standard
static var accessToken: String? {
    get { defaults.string(forKey: "access_token") }
    set { defaults.set(newValue, forKey: "access_token") }
}

static var refreshToken: String? {
    get { defaults.string(forKey: "refresh_token") }
    set { defaults.set(newValue, forKey: "refresh_token") }
}

static var hasToken: Bool { accessToken != nil }

static func clear() {
    defaults.removeObject(forKey: "access_token")
    defaults.removeObject(forKey: "refresh_token")
}
}
// MARK: - API Client
final class APIClient {
static let shared = APIClient()
private init() {}
private let baseURL = AppConfig.apiBaseURL

private let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    return d
}()

// MARK: - Public: JSON Request

/// Standard API call. Pass the expected response type as first arg.
///
/// Usage:
///   let user = try await APIClient.shared.request(
///       MeResponse.self, method: "GET", path: "/accounts/me/"
///   )
func request<T: Decodable>(
    _ type: T.Type,
    method: String,
    path: String,
    body: [String: Any]? = nil,
    auth: Bool = true
) async throws -> T {
    var (data, http) = try await perform(method: method, path: path, body: body, auth: auth)

    // On 401 with auth, try refresh then retry once
    if http.statusCode == 401 && auth {
        if await refreshTokens() {
            (data, http) = try await perform(method: method, path: path, body: body, auth: auth)
        } else {
            throw APIError.unauthorized
        }
    }

    return try decode(type, data: data, http: http)
}

// MARK: - Public: Raw Text (for SVG endpoints)

/// For endpoints that return raw text (SVG), not JSON.
func requestRaw(
    method: String = "GET",
    path: String,
    auth: Bool = true
) async throws -> String {
    var (data, http) = try await perform(method: method, path: path, auth: auth)

    if http.statusCode == 401 && auth {
        if await refreshTokens() {
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

/// For endpoints that return no body (204) or where you don't need the response.
func requestNoContent(
    method: String,
    path: String,
    body: [String: Any]? = nil,
    auth: Bool = true
) async throws {
    var (data, http) = try await perform(method: method, path: path, body: body, auth: auth)

    if http.statusCode == 401 && auth {
        if await refreshTokens() {
            (data, http) = try await perform(method: method, path: path, body: body, auth: auth)
        } else {
            throw APIError.unauthorized
        }
    }

    if (200...299).contains(http.statusCode) { return }
    try throwHTTPError(data: data, http: http)
}

// MARK: - Private: Raw HTTP

private func perform(
    method: String,
    path: String,
    body: [String: Any]? = nil,
    auth: Bool = true
) async throws -> (Data, HTTPURLResponse) {
    guard let url = URL(string: "\(baseURL)\(path)") else {
        throw APIError.badRequest("Invalid URL")
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if auth, let token = TokenStorage.accessToken {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    if let body = body {
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }

    let result: (Data, URLResponse)
    do {
        result = try await URLSession.shared.data(for: request)
    } catch {
        throw APIError.networkError
    }

    guard let http = result.1 as? HTTPURLResponse else {
        throw APIError.serverError
    }

    return (result.0, http)
}

// MARK: - Private: Decode

private func decode<T: Decodable>(_ type: T.Type, data: Data, http: HTTPURLResponse) throws -> T {
    if (200...299).contains(http.statusCode) {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    try throwHTTPError(data: data, http: http)
}

private func throwHTTPError(data: Data, http: HTTPURLResponse) throws -> Never {
    let err = try? decoder.decode(APIErrorResponse.self, from: data)
    let msg = err?.error ?? "Unknown error"

    switch http.statusCode {
    case 400: throw APIError.badRequest(msg)
    case 401: throw APIError.unauthorized
    case 403:
        if err?.code == "LIMIT_REACHED" { throw APIError.limitReached(msg) }
        if err?.code == "LOCKED" { throw APIError.locked(msg) }
        throw APIError.badRequest(msg)
    case 404: throw APIError.notFound
    default: throw APIError.serverError
    }
}

// MARK: - Private: Token Refresh

private func refreshTokens() async -> Bool {
    guard let refresh = TokenStorage.refreshToken else { return false }
    do {
        let (data, http) = try await perform(
            method: "POST",
            path: "/accounts/token/refresh/",
            body: ["refresh": refresh],
            auth: false
        )
        guard http.statusCode == 200 else { return false }
        let tokens = try decoder.decode(LoginResponse.self, from: data)
        TokenStorage.accessToken = tokens.access
        TokenStorage.refreshToken = tokens.refresh
        return true
    } catch {
        return false
    }
}
}
// 
