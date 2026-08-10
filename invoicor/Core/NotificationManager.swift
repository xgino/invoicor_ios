// =================================================================
// FILE: Core/NotificationManager.swift
// =================================================================
// Local push notifications based on user behavior.
// No server needed. All scheduled on-device.
//
// SETUP:
// 1. Add this file to Core/ folder (next to Analytics.swift)
// 2. Call NotificationManager.shared.requestPermission() after registration
// 3. Call schedule methods at integration points (see below)

import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - Permission
    
    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Analytics.shared.track(.notificationPermission, properties: [
                "granted": granted ? "true" : "false"
            ])
        }
    }
    
    // MARK: - After Registration
    // Call once after user registers successfully
    //
    // WHERE: In your RegisterScreen after successful registration
    //   NotificationManager.shared.schedulePostRegistration()
    
    func schedulePostRegistration() {
        // 24h: No invoice yet? Remind them
        schedule(
            id: "first_invoice_24h",
            title: "Your first invoice is waiting",
            body: "It takes 30 seconds. Pick a template, add a client, tap send.",
            delay: 24 * 60 * 60
        )
        
        // 7 days: Still no activity? Last nudge
        schedule(
            id: "inactive_7d",
            title: "Still have free invoices left",
            body: "Your templates and saved clients are waiting for you.",
            delay: 7 * 24 * 60 * 60
        )
    }
    
    // MARK: - After Invoice Created
    // Call every time an invoice is saved
    
    func onInvoiceCreated() {
        // Track count internally
        let key = "invoicor_invoice_count"
        let count = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(count, forKey: key)
        
        if count >= 1 {
            cancel("first_invoice_24h")
        }
        
        if count == 2 {
            schedule(
                id: "second_invoice",
                title: "You're on a roll",
                body: "Two invoices done. Keep the momentum going.",
                delay: 2 * 60 * 60
            )
        }
        
        // Reset 3-day inactivity timer
        cancel("inactive_3d")
        schedule(
            id: "inactive_3d",
            title: "Got a job done recently?",
            body: "Send the invoice now while it's fresh. Takes 30 seconds.",
            delay: 3 * 24 * 60 * 60
        )
        
        cancel("inactive_7d")
    }
    
    // MARK: - After Subscription
    // Call when user subscribes
    
    func onSubscribed() {
        cancelAll()
    }
    
    // MARK: - Private Helpers
    
    private func schedule(id: String, title: String, body: String, delay: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("[Notifications] Error scheduling \(id): \(error)")
            } else {
                Analytics.shared.track(.notificationScheduled, properties: ["id": id])
            }
        }
    }
    
    private func cancel(_ id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }
    
    private func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
