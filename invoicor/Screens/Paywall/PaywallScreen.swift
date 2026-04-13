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
                        Task { await auth.refreshMe() }
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
        .task { await loadOffering() }
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
    var auth = AuthManager.shared

    @State private var quizStep = 0
    @State private var invoiceVolume = ""
    @State private var needsAnalytics = false
    @State private var recommendedTier = "starter"

    private var gradientColors: [Color] {
        switch quizStep {
        case 0: return [Color(red: 0.15, green: 0.1, blue: 0.35), Color(red: 0.08, green: 0.08, blue: 0.2)]
        case 1: return [Color(red: 0.1, green: 0.15, blue: 0.35), Color(red: 0.05, green: 0.1, blue: 0.25)]
        default:
            return recommendedTier == "pro"
                ? [Color(red: 0.25, green: 0.1, blue: 0.35), Color(red: 0.15, green: 0.05, blue: 0.25)]
                : [Color(red: 0.1, green: 0.15, blue: 0.4), Color(red: 0.05, green: 0.1, blue: 0.3)]
        }
    }

    var body: some View {
        ZStack {
            if quizStep >= 3 {
                DirectPaywallView(tierId: recommendedTier, onDismiss: onDismiss)
            } else {
                quizContent
            }
        }
    }

    private var quizContent: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: quizStep)

            GeometryReader { geo in
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(Double.random(in: 0.02...0.06)))
                        .frame(width: CGFloat.random(in: 60...140))
                        .offset(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                        .blur(radius: CGFloat.random(in: 15...35))
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    if quizStep > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) { quizStep -= 1 }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left"); Text("Back")
                            }
                            .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium)).foregroundStyle(.white.opacity(0.5))
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).frame(height: 44)

                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i <= quizStep ? Color.white : Color.white.opacity(0.2))
                            .frame(width: i == quizStep ? 32 : 16, height: 4)
                            .animation(.easeInOut, value: quizStep)
                    }
                }
                .padding(.bottom, 32)

                Group {
                    switch quizStep {
                    case 0: question1
                    case 1: question2
                    case 2: recommendationView
                    default: EmptyView()
                    }
                }

                Spacer(); Spacer()
            }
        }
    }

    // MARK: - Questions

    private var question1: some View {
        VStack(spacing: 32) {
            quizIcon("doc.text.fill")
            VStack(spacing: 10) {
                Text("How many invoices do\nyou send per month?")
                    .font(.title2.weight(.bold)).foregroundStyle(.white).multilineTextAlignment(.center)
                Text("We'll find the perfect plan for you.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.6))
            }
            VStack(spacing: 12) {
                quizOption(icon: "doc.text", title: "Less than 10", subtitle: "I'm a freelancer or just starting") {
                    invoiceVolume = "few"
                    withAnimation(.easeInOut(duration: 0.3)) { quizStep = 1 }
                }
                quizOption(icon: "doc.on.doc.fill", title: "10 or more", subtitle: "I run a growing business") {
                    invoiceVolume = "many"
                    withAnimation(.easeInOut(duration: 0.3)) { quizStep = 1 }
                }
            }.padding(.horizontal, 24)
        }
    }

    private var question2: some View {
        VStack(spacing: 32) {
            quizIcon("chart.bar.fill")
            VStack(spacing: 10) {
                Text("Want to track\nyour revenue?")
                    .font(.title2.weight(.bold)).foregroundStyle(.white).multilineTextAlignment(.center)
                Text("Monthly earnings, client insights, and trends.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.6))
            }
            VStack(spacing: 12) {
                quizOption(icon: "chart.line.uptrend.xyaxis", title: "Yes, I want insights", subtitle: "Revenue charts and analytics") {
                    needsAnalytics = true; recommendedTier = determineTier()
                    withAnimation(.easeInOut(duration: 0.3)) { quizStep = 2 }
                }
                quizOption(icon: "paperplane.fill", title: "Just invoicing", subtitle: "I only need to send invoices") {
                    needsAnalytics = false; recommendedTier = determineTier()
                    withAnimation(.easeInOut(duration: 0.3)) { quizStep = 2 }
                }
            }.padding(.horizontal, 24)
        }
    }

    // MARK: - Recommendation

    private var recommendationView: some View {
        let isPro = recommendedTier == "pro"
        return VStack(spacing: 28) {
            ZStack {
                Circle().fill(isPro ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2)).frame(width: 100, height: 100)
                Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(isPro ? .purple : .blue)
            }
            VStack(spacing: 8) {
                Text("PERFECT MATCH").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.5)).tracking(2)
                Text(isPro ? "Pro" : "Starter").font(.system(size: 42, weight: .bold)).foregroundStyle(.white)
                Text(isPro ? "Analytics, higher limits, and priority support." : "Everything a freelancer needs for professional invoices.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            VStack(spacing: 14) {
                Button {
                    withAnimation { quizStep = 3 }
                } label: {
                    Text("See \(isPro ? "Pro" : "Starter") Plan")
                        .fontWeight(.bold).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(LinearGradient(colors: isPro ? [.purple, .purple.opacity(0.7)] : [.blue, .blue.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: isPro ? .purple.opacity(0.3) : .blue.opacity(0.3), radius: 12, y: 6)
                }
                Button {
                    recommendedTier = isPro ? "starter" : "pro"
                    withAnimation { quizStep = 3 }
                } label: {
                    Text("See \(isPro ? "Starter" : "Pro") plan instead")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.5))
                }
            }.padding(.horizontal, 24)
        }
    }

    // MARK: - Helpers

    private func determineTier() -> String {
        (invoiceVolume == "many" || needsAnalytics) ? "pro" : "starter"
    }

    private func quizIcon(_ name: String) -> some View {
        ZStack {
            Circle().fill(.white.opacity(0.1)).frame(width: 80, height: 80)
            Image(systemName: name).font(.system(size: 32)).foregroundStyle(.white)
        }
    }

    private func quizOption(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title3).foregroundStyle(.white.opacity(0.8)).frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(.white)
                    Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1), lineWidth: 1))
            )
        }
    }
}
