// Dev vs Prod: uses Swift compiler flags.
//
// HOW IT WORKS:
// - When you hit "Run" in Xcode (simulator) → DEBUG mode → uses localhost
// - When you "Archive" for App Store → RELEASE mode → uses production URL
// - Xcode sets the DEBUG flag automatically, you don't configure anything.
//
// To verify: Xcode → Build Settings → search "Swift Compiler - Custom Flags"
// You should see -DEBUG under "Other Swift Flags" for the Debug configuration.
// (Xcode adds this by default for new projects.)
import Foundation
enum AppConfig {
    static var apiBaseURL: String {
        #if DEBUG
        // return "http://localhost:8000/api"
        return "https://invoicor.com/api"
        #else
        return "https://invoicor.com/api"
        #endif
    }

    static var revenueCatAPIKey: String {
        // This is a PUBLIC api key — safe to embed in client code
        // Find it: RevenueCat dashboard → Project Settings → API Keys
        return "appl_LjyOfPrcxhqTgDvadATfkQGfsDw"
        // return "test_HvkBRckkUmOsrFZNsGfBDokvXbu"
    }

    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    
    // MARK: - Network Timeouts (used by APIClient)

    /// How long to wait for the server to start responding (seconds).
    static let requestTimeout: TimeInterval = 30

    /// How long to allow for the full resource download (seconds).
    static let resourceTimeout: TimeInterval = 60
    
    // MARK: - Mixpanel Analytics

    /// Public project token — safe to embed in client code (like RevenueCat key)
    /// Find it: Mixpanel dashboard → Settings → Project Settings → Project Token
    /// NOTE: Do NOT add the API Secret here — that's for server-side (Django) only
    static let mixpanelToken = "b0019ec749ec382f074059ac739ad297"

    /// EU data residency endpoint (we're EU-based)
    static let mixpanelServerURL = "https://api-eu.mixpanel.com"
}


