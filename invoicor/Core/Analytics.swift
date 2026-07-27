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

    // MARK: - Track (sends to BOTH Mixpanel + Meta)

    func track(_ event: Event, properties: Properties? = nil) {
        // Mixpanel
        Mixpanel.mainInstance().track(event: event.rawValue, properties: properties)

        // Meta - use standard events where possible for ad optimization
        switch event {
        case .appOpened:
            break // Meta SDK logs this automatically
        case .invoiceCompleted:
            AppEvents.shared.logEvent(.completedRegistration)
            NotificationManager.shared.onInvoiceCreated()
        case .paywallShown:
            AppEvents.shared.logEvent(.initiatedCheckout)
        case .subscriptionStarted:
            AppEvents.shared.logEvent(.subscribe)
            NotificationManager.shared.onSubscribed()
        default:
            AppEvents.shared.logEvent(AppEvents.Name(event.rawValue))
        }
    }

    // MARK: - Event Definitions

    enum Event: String {
        case appOpened           = "app_opened"
        case invoiceStarted      = "invoice_started"
        case invoiceCompleted    = "invoice_completed"
        case invoiceShared       = "invoice_shared"
        case paywallShown        = "paywall_shown"
        case subscriptionStarted = "subscription_started"
        case notificationPermission = "notification_permission"
        case notificationScheduled  = "notification_scheduled"
    }
}
