// Components/ReviewManager.swift
// Handles App Store review prompts at strategic moments.
//
// Strategy:
// - Ask after 3rd invoice marked as paid (they've gotten real value)
// - Ask again after 10th paid invoice (if they dismissed the first time)
// - Ask again after 25th paid invoice (long-term user)
// - Never more than once per 3 months (Apple enforces this too)
// - Apple's API shows the prompt at most 3 times per year
//
// Usage: Call ReviewManager.invoicePaid() each time an invoice is marked paid.

import StoreKit
import UIKit

enum ReviewManager {

    // UserDefaults keys
    private static let paidCountKey = "review_paid_invoice_count"
    private static let lastPromptKey = "review_last_prompt_date"

    // Ask at these milestones
    private static let milestones: Set<Int> = [3, 10, 25]

    // Minimum days between prompts
    private static let minDaysBetween = 90

    /// Call this every time an invoice status changes to "paid".
    static func invoicePaid() {
        let defaults = UserDefaults.standard
        let newCount = defaults.integer(forKey: paidCountKey) + 1
        defaults.set(newCount, forKey: paidCountKey)

        // Only prompt at milestones
        guard milestones.contains(newCount) else { return }

        // Don't prompt too frequently
        if let lastDate = defaults.object(forKey: lastPromptKey) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            guard daysSince >= minDaysBetween else { return }
        }

        // Show the in-app review prompt
        requestReview()
    }

    /// Shows Apple's native in-app review dialog.
    /// The user rates without leaving the app.
    /// Apple may silently suppress this if called too often — that's fine.
    private static func requestReview() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
                UserDefaults.standard.set(Date(), forKey: lastPromptKey)
            }
        }
    }
}
