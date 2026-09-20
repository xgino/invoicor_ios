// RootView.swift
// Onboarding removed — goes straight to dashboard after login.
// Business profile editing happens in Settings.
import SwiftUI
import RevenueCat
import RevenueCatUI

struct RootView: View {
    var auth = AuthManager.shared
    var onboarding = OnboardingManager.shared
    @State private var splashDone = false
    @State private var trialOfferSeen = false
    @State private var showTrialOffer = false
    
    var body: some View {
        Group {
            if !splashDone {
                SplashScreen {
                    withAnimation { splashDone = true }
                }
            } else {
                switch auth.state {
                case .loading:
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .unauthenticated:
                    OnboardingFlow()
                    .transition(.opacity)
                        
                case .authenticated:
                    if !auth.hasBusinessProfile {
                        BusinessWizard()
                            .transition(.opacity)
                    } else if !trialOfferSeen && !UserDefaults.standard.bool(forKey: "seen_trial_offer") {
                        OnboardingPaywallFlow(onFinish: {
                            UserDefaults.standard.set(true, forKey: "seen_trial_offer")
                            trialOfferSeen = true
                        })
                        .transition(.opacity)
                    } else {
                        MainTabView()
                            .transition(.opacity)
                    }
                case .error(let message):
                    VStack(spacing: 20) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Connection Issue")
                            .font(.title2.bold())
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button {
                            Task { await auth.checkSession() }
                        } label: {
                            Text("Try Again")
                                .font(.headline)
                                .frame(maxWidth: 200)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.state)
    }
}

// MARK: - Main Tab Bar

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showCreate = false
    @State private var showReviewGate = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeScreen() }
                .tabItem { Image(systemName: "house.fill"); Text("Home") }
                .tag(0)

            NavigationStack { InvoiceListScreen() }
                .tabItem { Image(systemName: "doc.text.fill"); Text("Invoices") }
                .tag(1)

            Text("")
                .tabItem { Image(systemName: "plus.circle.fill"); Text("Create") }
                .tag(2)

            NavigationStack { LibraryScreen() }
                .tabItem { Image(systemName: "folder.fill"); Text("Library") }
                .tag(3)

            NavigationStack { SettingsScreen() }
                .tabItem { Image(systemName: "gearshape.fill"); Text("Settings") }
                .tag(4)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                selectedTab = oldValue
                showCreate = true
            }
        }
        .fullScreenCover(isPresented: $showCreate) {
            CreateInvoiceScreen(isPresented: $showCreate)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: .showReviewGate
        )) { _ in
            showReviewGate = true
        }
        .sheet(isPresented: $showReviewGate) {
            ReviewGateSheet()
        }
    }
}

// Onboarding Paywall Flow
private struct OnboardingPaywallFlow: View {
    let onFinish: () -> Void
    @State private var paywallDismissed = false
    @State private var offering: Offering? = nil

    var body: some View {
        if paywallDismissed {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "gift.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.orange)
                Text("3 invoices on us")
                    .font(.system(size: 28, weight: .bold))
                Text("Try it out for free. Send real invoices,\nget paid first. Then decide.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
                Button { onFinish() } label: {
                    Text("Send my first invoice")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        } else if let offering {
            NavigationStack {
                PaywallView(offering: offering, displayCloseButton: false)
                    .onPurchaseCompleted { _ in
                        Task { await AuthManager.shared.refreshMe() }
                        onFinish()
                    }
                    .onRestoreCompleted { _ in
                        Task { await AuthManager.shared.refreshMe() }
                        onFinish()
                    }
                    .overlay(alignment: .topTrailing) {
                        Button { withAnimation { paywallDismissed = true } } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(.top, 10)
                        .padding(.trailing, 10)
                    }
            }
        } else {
            ProgressView().task {
                let offerings = try? await Purchases.shared.offerings()
                offering = offerings?.offering(identifier: "onboarding_trail") ?? offerings?.current
            }
        }
    }
}
