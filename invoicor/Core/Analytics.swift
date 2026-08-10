import Foundation
import Mixpanel
import FBSDKCoreKit
import GoMarketMe

final class Analytics {

    static let shared = Analytics()
    private init() {}

    // MARK: - Setup (call once in InvoicorApp)

    func configure() {
        // Mixpanel
        Mixpanel.initialize(
            token: AppConfig.mixpanelToken,
            trackAutomaticEvents: false,
            serverURL: AppConfig.mixpanelServerURL
        )

        #if DEBUG
        Mixpanel.mainInstance().loggingEnabled = true
        #endif

        // Meta SDK - auto-logs installs and sessions
        ApplicationDelegate.shared.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )
        
        // GoMarketMe Affiliate
        GoMarketMe.shared.initialize(apiKey: AppConfig.goMarketMeApiKey)
    }

    // MARK: - Identity

    func identify(userId: String) {
        Mixpanel.mainInstance().identify(distinctId: userId)
    }

    func reset() {
        Mixpanel.mainInstance().reset()
    }

    // MARK: - Track
    //
    // WHERE EACH EVENT LIVES:
    //
    // iOS only (Mixpanel + Meta):
    //   app_opened            → Mixpanel only, Meta logs automatically
    //   invoice_started       → Mixpanel + Meta (completedRegistration)
    //   paywall_shown         → Mixpanel + Meta (initiatedCheckout)
    //   notification_permission → Mixpanel only
    //   notification_scheduled  → Mixpanel only
    //
    // Django only (AppEvent model, NOT tracked here):
    //   invoice_created       → API fires on save
    //   invoice_sent          → API fires on status change
    //   invoice_paid          → API fires on status change
    //   invoice_duplicated    → API fires on duplicate
    //   pdf_exported          → API fires on export
    //   client_created        → API fires on save
    //   product_created       → API fires on save
    //   profile_created       → API fires on save
    //   feedback_submitted    → API fires on save
    //   subscription_started  → RevenueCat webhook
    //   subscription_cancelled → RevenueCat webhook
    //   paywall_hit           → API fires on limit reached
    //   onboarding_step       → API fires via OnboardingManager
    //

    func track(_ event: Event, properties: Properties? = nil) {
            // ── Mixpanel (all iOS events) ──
            Mixpanel.mainInstance().track(event: event.rawValue, properties: properties)

            // ── Meta (only specific events for ad optimization) ──
            switch event {
            case .appOpened:
                break // Meta SDK auto-logs sessions
            case .invoiceStarted:
                // Tells Meta "user took a key action" → optimizes for these users
                AppEvents.shared.logEvent(.completedRegistration)
                NotificationManager.shared.onInvoiceCreated()
            case .paywallShown:
                // Tells Meta "user is close to purchase" → optimizes for these users
                AppEvents.shared.logEvent(.initiatedCheckout)
            case .notificationPermission, .notificationScheduled:
                break // Mixpanel only, Meta doesn't need these
            }
        }

        // MARK: - Events (iOS-only, Django handles the rest)

        enum Event: String {
            case appOpened              = "app_opened"
            case invoiceStarted        = "invoice_started"
            case paywallShown          = "paywall_shown"
            case notificationPermission = "notification_permission"
            case notificationScheduled  = "notification_scheduled"
        }
    }
