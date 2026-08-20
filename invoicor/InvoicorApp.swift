// InvoicorApp.swift
// Configures RevenueCat on launch, then shows RootView.
import SwiftUI
import RevenueCat
import GoogleSignIn

@main
struct InvoicorApp: App {
    init() {
        // Only enable debug logging in development
        if AppConfig.isDebug {
            Purchases.logLevel = .debug
        }
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
        Analytics.shared.configure()
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: AppConfig.googleClientID)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
