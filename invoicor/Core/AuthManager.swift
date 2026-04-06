// Core/AuthManager.swift
// Manages auth state for the entire app.
// RootView observes auth.state to decide which screen to show.
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
            Task { await checkSession() }
        } else {
            state = .unauthenticated
        }
    }

    // MARK: - Session Check (on app launch)

    private func checkSession() async {
        do {
            let me = try await APIClient.shared.request(
                MeResponse.self, method: "GET", path: "/accounts/me/"
            )
            await MainActor.run {
                self.meResponse = me
                self.state = .authenticated
            }
        } catch {
            await MainActor.run { self.performLogout() }
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async throws {
        let tokens = try await APIClient.shared.request(
            LoginResponse.self,
            method: "POST",
            path: "/accounts/login/",
            body: ["email": email, "password": password],
            auth: false
        )
        TokenStorage.accessToken = tokens.access
        TokenStorage.refreshToken = tokens.refresh

        let me = try await APIClient.shared.request(
            MeResponse.self, method: "GET", path: "/accounts/me/"
        )
        await MainActor.run {
            self.meResponse = me
            self.state = .authenticated
        }
    }

    // MARK: - Register

    func register(email: String, password: String) async throws {
        let _ = try await APIClient.shared.request(
            RegisterResponse.self,
            method: "POST",
            path: "/accounts/register/",
            body: ["email": email, "password": password],
            auth: false
        )
        try await login(email: email, password: password)
    }

    // MARK: - Refresh (call after profile updates, invoice creation, etc.)

    func refreshMe() async {
        if let me = try? await APIClient.shared.request(
            MeResponse.self, method: "GET", path: "/accounts/me/"
        ) {
            await MainActor.run { self.meResponse = me }
        }
    }

    // MARK: - Logout

    func logout() { performLogout() }

    private func performLogout() {
        TokenStorage.clear()
        meResponse = nil
        state = .unauthenticated
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        try await APIClient.shared.requestNoContent(
            method: "DELETE", path: "/accounts/me/delete/"
        )
        await MainActor.run { self.performLogout() }
    }
}
