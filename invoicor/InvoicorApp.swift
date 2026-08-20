// InvoicorApp.swift
// Configures RevenueCat on launch, then shows RootView.
import SwiftUI
import RevenueCat
import GoogleSignIn
import PostHog

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
        
        // ── PostHog ──
        let phConfig = PostHogConfig(projectToken: AppConfig.posthogAPIKey, host: AppConfig.posthogHost)
        phConfig.debug = false
        phConfig.captureApplicationLifecycleEvents = true
        phConfig.captureScreenViews = true
        phConfig.sessionReplay = true
        phConfig.sessionReplayConfig.screenshotMode = true      // required for SwiftUI
        phConfig.sessionReplayConfig.maskAllTextInputs = true   // GDPR — hide client names/amounts
        phConfig.sessionReplayConfig.maskAllImages = true
        PostHogSDK.shared.setup(phConfig)
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
