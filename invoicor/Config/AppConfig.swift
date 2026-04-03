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
            // Simulator / development: your local Django server
            return "http://localhost:8000/api"
        #else
            // App Store / TestFlight: your production server
            return "https://api.invoicor.com/api"
        #endif
    }
    
    static var isDebug: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
}
//
