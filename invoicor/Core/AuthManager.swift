// =================================================================
// FILE: Core/AuthManager.swift
// =================================================================
// Observable auth state manager. Drives the root navigation:
// .loading → show splash, .authenticated → show main, .unauthenticated → show login.
//
// PRODUCTION NOTES:
// - Entire class is @MainActor since all state drives SwiftUI.
// - Session check distinguishes auth failures (→ logout) from network
//   errors (→ stay on splash, let user retry). No more "flaky wifi = logout".
// - RevenueCat integration is fire-and-forget with error logging.

import Foundation
import Observation
import RevenueCat

// MARK: - Auth State

/// Drives root navigation. Equatable for SwiftUI conditional views.
enum AuthState: Equatable, Sendable {
    case loading
    case authenticated
    case unauthenticated
    /// Network or server error during session check. User can retry.
    case error(String)

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading): return true
        case (.authenticated, .authenticated): return true
        case (.unauthenticated, .unauthenticated): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Auth Manager

@MainActor
@Observable
final class AuthManager {
    // MARK: Singleton
    static let shared = AuthManager()

    // MARK: Published State
    var state: AuthState = .loading
    private(set) var meResponse: MeResponse?

    // MARK: Convenience Accessors
    var currentUser: User?           { meResponse?.user }
    var subscription: SubscriptionInfo? { meResponse?.subscription }
    var usage: UsageInfo?            { meResponse?.usage }
    var limits: LimitsInfo?          { meResponse?.limits }

    /// Whether the user is currently on a paid plan.
    var isPaid: Bool {
        guard let tier = currentUser?.tier else { return false }
        return tier != "free"
    }

    // MARK: Init

    private init() {
        if TokenStorage.hasToken {
            state = .loading
            Task { await checkSession() }
        } else {
            state = .unauthenticated
        }
    }

    // MARK: - Session Check (App Launch / Foreground)

    /// Validates the stored token by calling /me.
    /// - Auth errors (401) → logout (token is invalid/expired beyond refresh).
    /// - Network/server errors → `.error` state so user can retry without losing tokens.
    func checkSession() async {
        state = .loading
        do {
            let me = try await APIClient.shared.request(
                MeResponse.self, method: "GET", path: "/accounts/me/"
            )
            meResponse = me
            state = .authenticated
            linkRevenueCat(userId: me.user.publicId)
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                // Token is truly invalid — clean logout
                performLogout()
            case .networkError(let msg):
                // Don't destroy tokens for a network blip
                state = .error(msg)
            default:
                // Server error, decoding error, etc. — don't logout
                state = .error(error.errorDescription ?? "Something went wrong")
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Login

    /// Authenticate with email and password.
    /// - Throws: `APIError` on failure (bad credentials, network, etc.)
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
        meResponse = me
        state = .authenticated
        linkRevenueCat(userId: me.user.publicId)
    }

    // MARK: - Register

    /// Create a new account and immediately log in.
    /// - Throws: `APIError` on failure (duplicate email, validation, network, etc.)
    func register(email: String, password: String) async throws {
        _ = try await APIClient.shared.request(
            RegisterResponse.self,
            method: "POST",
            path: "/accounts/register/",
            body: ["email": email, "password": password],
            auth: false
        )
        // login() handles token storage, /me fetch, and RevenueCat linking
        try await login(email: email, password: password)
    }

    // MARK: - Apple Sign In

    /// Authenticate with Apple identity token.
    /// Backend verifies the token with Apple, creates or links the account,
    /// and returns JWT access/refresh tokens.
    func loginWithApple(identityToken: String, fullName: String?, email: String?) async throws {
        var body: [String: Any] = ["identity_token": identityToken]
        if let name = fullName { body["full_name"] = name }
        if let email = email { body["email"] = email }

        let tokens = try await APIClient.shared.request(
            LoginResponse.self,
            method: "POST",
            path: "/accounts/auth/apple/",
            body: body,
            auth: false
        )
        TokenStorage.accessToken = tokens.access
        TokenStorage.refreshToken = tokens.refresh

        let me = try await APIClient.shared.request(
            MeResponse.self, method: "GET", path: "/accounts/me/"
        )
        meResponse = me
        state = .authenticated
        linkRevenueCat(userId: me.user.publicId)
    }

    // MARK: - Google Sign In (placeholder)

    /// Authenticate with Google ID token.
    /// Same pattern as Apple — backend verifies, creates/links account, returns JWTs.
    func loginWithGoogle(idToken: String) async throws {
        let tokens = try await APIClient.shared.request(
            LoginResponse.self,
            method: "POST",
            path: "/accounts/auth/google/",
            body: ["id_token": idToken],
            auth: false
        )
        TokenStorage.accessToken = tokens.access
        TokenStorage.refreshToken = tokens.refresh

        let me = try await APIClient.shared.request(
            MeResponse.self, method: "GET", path: "/accounts/me/"
        )
        meResponse = me
        state = .authenticated
        linkRevenueCat(userId: me.user.publicId)
    }

    // MARK: - Refresh User Data

    /// Re-fetch /me after profile updates, invoice creation, purchases, etc.
    /// Silently fails — caller should handle their own error state if needed.
    func refreshMe() async {
        do {
            let me = try await APIClient.shared.request(
                MeResponse.self, method: "GET", path: "/accounts/me/"
            )
            meResponse = me
        } catch {
            #if DEBUG
            print("⚠️ [Auth] refreshMe failed: \(error)")
            #endif
        }
    }

    // MARK: - Logout

    /// Clear local state, tokens, and RevenueCat session.
    func logout() {
        logOutRevenueCat()
        performLogout()
    }

    // MARK: - Delete Account

    /// Permanently delete the user's account on the server, then clean up locally.
    /// - Throws: `APIError` if the server rejects the deletion.
    func deleteAccount() async throws {
        try await APIClient.shared.requestNoContent(
            method: "DELETE", path: "/accounts/me/delete/"
        )
        logOutRevenueCat()
        performLogout()
    }

    // MARK: - Private: Local Cleanup

    private func performLogout() {
        TokenStorage.clear()
        meResponse = nil
        state = .unauthenticated
    }

    // MARK: - Private: RevenueCat

    /// Link RevenueCat to the Django user. Fire-and-forget.
    private func linkRevenueCat(userId: String) {
        Task.detached(priority: .utility) {
            do {
                let (_, _) = try await Purchases.shared.logIn(userId)
                #if DEBUG
                print("✅ [RC] Linked to user: \(userId)")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ [RC] logIn error: \(error)")
                #endif
            }
        }
    }

    /// Disconnect RevenueCat. Fire-and-forget.
    private func logOutRevenueCat() {
        Task.detached(priority: .utility) {
            do {
                _ = try await Purchases.shared.logOut()
                #if DEBUG
                print("✅ [RC] Logged out")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ [RC] logOut error: \(error)")
                #endif
            }
        }
    }
}
