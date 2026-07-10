//
//  Analytics.swift
//  invoicor
//
//  Created by Gin on 09/07/2026.
//

import Foundation
import Mixpanel

final class Analytics {

    static let shared = Analytics()
    private init() {}

    // MARK: - Setup (call once in InvoicorApp)

    func configure() {
        Mixpanel.initialize(
            token: AppConfig.mixpanelToken,
            trackAutomaticEvents: false,
            serverURL: AppConfig.mixpanelServerURL,
        )

        #if DEBUG
        Mixpanel.mainInstance().loggingEnabled = true
        #endif
    }

    // MARK: - Identity

    func identify(userId: String) {
        Mixpanel.mainInstance().identify(distinctId: userId)
    }

    func reset() {
        Mixpanel.mainInstance().reset()
    }

    // MARK: - Core Funnel Events

    func track(_ event: Event, properties: Properties? = nil) {
        Mixpanel.mainInstance().track(event: event.rawValue, properties: properties)
    }

    // MARK: - Event Definitions

    enum Event: String {
        case appOpened           = "app_opened"
        case invoiceStarted      = "invoice_started"
        case invoiceCompleted    = "invoice_completed"
        case invoiceShared       = "invoice_shared"
        case paywallShown        = "paywall_shown"
        case subscriptionStarted = "subscription_started"
    }
}
