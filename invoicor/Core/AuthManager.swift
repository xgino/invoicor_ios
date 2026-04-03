// Now uses the explicit type parameter pattern:
//   request(LoginResponse.self, method: ...)
// instead of:
//   let x: LoginResponse = request(method: ...)
import Foundation
import Observation
enum AuthState: Equatable {
case loading
case authenticated
case unauthenticated
}
@Observable
final class AuthManager {
static let shared = AuthManager()
var state: AuthState = .loading
var meResponse: MeResponse?

var currentUser: User? { meResponse?.user }
var subscription: SubscriptionInfo? { meResponse?.subscription }
var usage: UsageInfo? { meResponse?.usage }
var limits: LimitsInfo? { meResponse?.limits }

private init() {
    if TokenStorage.hasToken {
        state = .loading
        Task {
            do {
                let me = try await APIClient.shared.request(
                    MeResponse.self,
                    method: "GET",
                    path: "/accounts/me/"
                )
                await MainActor.run {
                    self.meResponse = me
                    self.state = .authenticated
                }
            } catch {
                await MainActor.run {
                    self.performLogout()
                }
            }
        }
    } else {
        state = .unauthenticated
    }
}

// MARK: - Login

func login(email: String, password: String) async throws {
    let body: [String: Any] = ["email": email, "password": password]

    // Explicit type as first argument — no inference needed
    let tokens = try await APIClient.shared.request(
        LoginResponse.self,
        method: "POST",
        path: "/accounts/login/",
        body: body,
        auth: false
    )

    TokenStorage.accessToken = tokens.access
    TokenStorage.refreshToken = tokens.refresh

    let me = try await APIClient.shared.request(
        MeResponse.self,
        method: "GET",
        path: "/accounts/me/"
    )

    await MainActor.run {
        self.meResponse = me
        self.state = .authenticated
    }
}

// MARK: - Register

func register(email: String, password: String) async throws {
    let body: [String: Any] = ["email": email, "password": password]

    // Don't need the response — just need it to succeed
    try await APIClient.shared.requestNoContent(
        method: "POST",
        path: "/accounts/register/",
        body: body,
        auth: false
    )

    // Auto-login
    try await login(email: email, password: password)
}

// MARK: - Logout

func logout() {
    performLogout()
}

private func performLogout() {
    TokenStorage.clear()
    meResponse = nil
    state = .unauthenticated
}

// MARK: - Delete Account

func deleteAccount() async throws {
    try await APIClient.shared.requestNoContent(
        method: "DELETE",
        path: "/accounts/me/delete/"
    )
    await MainActor.run {
        self.performLogout()
    }
}
}
// 
