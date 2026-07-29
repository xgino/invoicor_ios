// Screens/PaywallScreen.swift
// Two entry points:
//   1. PaywallScreen()              → Quiz flow → recommendation → RevenueCat paywall
//   2. PaywallScreen(tier: "pro")   → Direct to that tier's RevenueCat paywall (no quiz)
//
// Used from:
//   - Settings "Upgrade" button     → PaywallScreen()  (quiz)
//   - Template lock "Upgrade to X"  → PaywallScreen(tier: "pro")  (direct)
//   - Limit reached errors          → PaywallScreen(tier: "starter")  (direct)

import SwiftUI
import RevenueCat
import RevenueCatUI
import GoMarketMe

struct PaywallScreen: View {
    var tier: String? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let tier {
            DirectPaywallView(tierId: tier, onDismiss: { dismiss() })
        } else {
            UpgradeQuizView(onDismiss: { dismiss() })
        }
    }
}

// MARK: - Direct Paywall (no quiz)

struct DirectPaywallView: View {
    let tierId: String
    let onDismiss: () -> Void
    var auth = AuthManager.shared

    @State private var offering: Offering? = nil
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading plan…").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            } else if let offering {
                PaywallView(offering: offering, displayCloseButton: true)
                    .onPurchaseCompleted { _ in
                        Analytics.shared.track(.subscriptionStarted)
                        Task {
                            _ = await GoMarketMe.shared.syncAllTransactions()
                            await auth.refreshMe()
                        }
                        onDismiss()
                    }
                    .onRestoreCompleted { _ in
                        Task { await auth.refreshMe() }
                        onDismiss()
                    }
            } else {
                planNotAvailableView
            }
        }
        .task {
            Analytics.shared.track(.paywallShown)
            await loadOffering()
        }
    }

    private func loadOffering() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            await MainActor.run {
                offering = offerings.offering(identifier: tierId) ?? offerings.current
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private var planNotAvailableView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Plan not available yet").font(.title3.weight(.bold))
            Text("We're setting up subscription options.\nPlease check back shortly.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Close") { onDismiss() }.buttonStyle(.borderedProminent).padding(.top, 8)
        }
        .padding(40)
    }
}

// MARK: - Quiz Flow

struct UpgradeQuizView: View {
    let onDismiss: () -> Void
    
    @State private var selectedTier = "starter"
    @State private var showPaywall = false
    
    var body: some View {
        if showPaywall {
            DirectPaywallView(tierId: selectedTier, onDismiss: onDismiss)
        } else {
            pickScreen
        }
    }
    
    private var pickScreen: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.2),
                    Color(red: 0.15, green: 0.1, blue: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Text("You've outgrown Free")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                    
                    Text("Which fits you best?")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.bottom, 32)
                
                VStack(spacing: 14) {
                    tierCard(
                        tier: "starter",
                        icon: "paperplane.fill",
                        color: .blue,
                        title: "Starter",
                        subtitle: "For freelancers and side projects"
                    )
                    
                    tierCard(
                        tier: "pro",
                        icon: "rocket.fill",
                        color: .purple,
                        title: "Pro",
                        subtitle: "For growing businesses"
                    )
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                Button {
                    withAnimation { showPaywall = true }
                } label: {
                    Text("See Plan")
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: selectedTier == "pro"
                                    ? [.purple, .purple.opacity(0.7)]
                                    : [.blue, .blue.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .task {
            Analytics.shared.track(.paywallShown)
        }
    }
    
    private func tierCard(
        tier: String,
        icon: String,
        color: Color,
        title: String,
        subtitle: String
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTier = tier
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(
                            selectedTier == tier ? color : .white.opacity(0.2),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)
                    
                    if selectedTier == tier {
                        Circle()
                            .fill(color)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedTier == tier
                        ? color.opacity(0.12)
                        : .white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                selectedTier == tier
                                    ? color.opacity(0.4)
                                    : .white.opacity(0.08),
                                lineWidth: 1.5
                            )
                    )
            )
        }
    }
}
