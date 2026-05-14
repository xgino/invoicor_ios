// =================================================================
// FILE: Core/OnboardingManager.swift
// =================================================================
// Manages onboarding state. Stores progress locally during pre-auth
// flow, syncs to API anonymously, links to user after registration.

import Foundation
import Observation

// MARK: - API Response Models

struct OnboardingConfig: Codable, Sendable {
    let screens: [OnboardingScreenConfig]
}

struct OnboardingScreenConfig: Codable, Sendable, Identifiable {
    let id: String
    let type: String
    let headline: String?
    let subtext: String?
    let options: [OnboardingOption]?
    let skipForIcp: [String]?
    let content: [String: OnboardingContent]?
    let freeFeatures: [String]?
    let upgradeText: String?
    let ctaPrimary: String?
    let ctaSecondary: String?
}

struct OnboardingOption: Codable, Sendable, Identifiable {
    let key: String
    let title: String
    let subtitle: String
    let icon: String
    var id: String { key }
}

struct OnboardingContent: Codable, Sendable {
    let headline: String
    let points: [OnboardingPoint]

    enum CodingKeys: String, CodingKey { case headline, points }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        headline = try c.decode(String.self, forKey: .headline)
        if let obj = try? c.decode([OnboardingPoint].self, forKey: .points) {
            points = obj
        } else if let strs = try? c.decode([String].self, forKey: .points) {
            points = strs.map { OnboardingPoint(icon: nil, text: $0) }
        } else {
            points = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(headline, forKey: .headline)
        try c.encode(points, forKey: .points)
    }
}

struct OnboardingPoint: Codable, Sendable, Identifiable {
    let icon: String?
    let text: String
    var id: String { text }
}

struct OnboardingSessionResponse: Codable, Sendable {
    let sessionId: String
    let icp: String
    let status: String
    let planViewed: String?
    let startedAt: String?
    let userLinked: Bool?
}

struct OnboardingLinkResponse: Codable, Sendable {
    let onboarding: OnboardingSessionResponse?
    let hasBusinessProfile: Bool
}

// MARK: - Manager

@MainActor
@Observable
final class OnboardingManager {
    static let shared = OnboardingManager()

    var config: OnboardingConfig?
    var selectedICP: String = ""
    var isLoading = false

    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "onboarding_completed")
    
    var isFirstLaunch: Bool = !UserDefaults.standard.bool(forKey: "onboarding_seen")

    var sessionId: String {
        if let existing = UserDefaults.standard.string(forKey: "onboarding_session_id") {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "onboarding_session_id")
        return id
    }

    private init() {
        selectedICP = UserDefaults.standard.string(forKey: "onboarding_icp") ?? ""
    }

    // MARK: - Fetch Config (no auth)

    func fetchConfig() async {
        if config != nil { return }
        isLoading = true
        do {
            config = try await APIClient.shared.request(
                OnboardingConfig.self,
                method: "GET",
                path: "/accounts/onboarding/config/",
                auth: false
            )
        } catch {
            #if DEBUG
            print("⚠️ [Onboarding] Config fetch failed: \(error)")
            #endif
        }
        isLoading = false
    }

    // MARK: - Track Step (no auth)

    func trackStep(_ status: String, icp: String? = nil, planViewed: String? = nil) {
        UserDefaults.standard.set(true, forKey: "onboarding_seen")
        if let icp {
            selectedICP = icp
            UserDefaults.standard.set(icp, forKey: "onboarding_icp")
        }

        Task { [sessionId, selectedICP] in
            var body: [String: Any] = ["session_id": sessionId, "status": status]
            if let icp { body["icp"] = icp }
            else if !selectedICP.isEmpty { body["icp"] = selectedICP }
            if let plan = planViewed { body["plan_viewed"] = plan }

            do {
                _ = try await APIClient.shared.request(
                    OnboardingSessionResponse.self,
                    method: "POST",
                    path: "/accounts/onboarding/session/",
                    body: body,
                    auth: false
                )
            } catch {
                #if DEBUG
                print("⚠️ [Onboarding] Track failed: \(error)")
                #endif
            }
        }
    }

    // MARK: - Link to User (after registration)

    func linkToUser() async {
        do {
            _ = try await APIClient.shared.request(
                OnboardingLinkResponse.self,
                method: "POST",
                path: "/accounts/onboarding/link/",
                body: ["session_id": sessionId, "status": "registered"],
                auth: true
            )
        } catch {
            #if DEBUG
            print("⚠️ [Onboarding] Link failed: \(error)")
            #endif
        }
    }

    // MARK: - Complete

    func markCompleted() {
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        hasCompletedOnboarding = true  // ← triggers RootView re-render
        trackStep("completed")
    }
}
