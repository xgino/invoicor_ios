// Components/ReviewManager.swift
// Review gate: Yes/No → Apple review or Feedback form
//
// HOW IT WORKS:
// 1. invoicePaid() is called every time user marks an invoice as "paid"
// 2. We count total paid invoices in UserDefaults
// 3. At milestones (1, 3, 10, 25) we check if 90+ days since last prompt
// 4. If eligible, we post a notification that triggers ReviewGateSheet
// 5. Sheet shows "Enjoying Invoicor?" with Yes/No
// 6. Yes → Apple's native SKStoreReviewController (likely 5 stars)
// 7. No → Feedback form that POSTs to our /feedback/ API (catches bad reviews)
// 8. "Not now" → dismissed, will try at next milestone
//
// WHY A GATE:
// Without: unhappy user goes straight to App Store → 1 star review
// With: unhappy user tells US what's wrong → we fix it → no public bad review
//
// APPLE LIMITS:
// Apple shows the review popup max 3 times per 365 days.
// Our Yes/No gate has no limit. Only "Yes" triggers Apple's popup.
// So we can ask at every milestone, but Apple's popup only shows 3x/year.

import StoreKit
import UIKit

enum ReviewManager {
    // UserDefaults keys
    private static let paidCountKey = "review_paid_invoice_count"
    private static let lastPromptKey = "review_last_prompt_date"

    // Milestones: show review gate at these paid invoice counts
    // 1  = first value received (early positive signal)
    // 3  = repeated value (they trust the app now)
    // 10 = power user
    // 25 = long-term user
    private static let milestones: Set<Int> = [1, 3, 10, 25]

    // Minimum days between prompts (Apple enforces ~120 days,
    // we use 90 for our gate since gate != Apple popup)
    private static let minDaysBetween = 90

    /// Call this every time an invoice status changes to "paid".
    /// Safe to call multiple times. Only triggers at milestones.
    static func invoicePaid() {
        let defaults = UserDefaults.standard
        let newCount = defaults.integer(forKey: paidCountKey) + 1
        defaults.set(newCount, forKey: paidCountKey)

        // Only show gate at milestone counts
        guard milestones.contains(newCount) else { return }

        // Don't prompt too frequently (except first milestone)
        if newCount > 1, let lastDate = defaults.object(forKey: lastPromptKey) as? Date {
            let daysSince = Calendar.current.dateComponents(
                [.day], from: lastDate, to: Date()
            ).day ?? 0
            guard daysSince >= minDaysBetween else { return }
        }

        // Post notification → root view shows ReviewGateSheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NotificationCenter.default.post(
                name: .showReviewGate, object: nil
            )
        }
    }

    /// Called when user taps "Yes, I love it!" in the gate.
    /// This is the ONLY place that triggers Apple's review popup.
    static func requestReview() {
        if let scene = UIApplication.shared.connectedScenes
            .first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
            UserDefaults.standard.set(Date(), forKey: lastPromptKey)
        }
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let showReviewGate = Notification.Name("showReviewGate")
}
