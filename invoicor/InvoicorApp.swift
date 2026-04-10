// InvoicorApp.swift
// Configures RevenueCat on launch, then shows RootView.
import SwiftUI
import RevenueCat

@main
struct InvoicorApp: App {
    init() {
        // Only enable debug logging in development
        if AppConfig.isDebug {
            Purchases.logLevel = .debug
        }
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
