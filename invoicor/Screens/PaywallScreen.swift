// Screens/PaywallScreen.swift
// Full-screen paywall with swipeable tier cards.
// Default view: Starter (middle). Swipe left: Free. Swipe right: Pro, Business.
// Gradient background, modern design, Apple-required legal text.
import SwiftUI

struct PaywallScreen: View {
    @Environment(\.dismiss) private var dismiss
    var auth = AuthManager.shared

    @State private var selectedTier = 1  // 0=Free, 1=Starter, 2=Pro, 3=Business
    @State private var billingCycle = 0  // 0=monthly, 1=yearly

    private let tiers = [
        TierInfo(
            name: "Free", tagline: "Get started",
            monthlyPrice: "$0", yearlyPrice: "$0",
            color: Color(.systemGray4),
            features: [
                TierFeature(name: "3 invoices", included: true),
                TierFeature(name: "Unlimited items", included: true),
                TierFeature(name: "1 business profile", included: true),
                TierFeature(name: "Unlimited Clients", included: true),
                TierFeature(name: "Basic templates", included: true),
                TierFeature(name: "Revenue analytics", included: true),
            ],
            ctaText: "Current Plan",
            isFree: true
        ),
        TierInfo(
            name: "Starter", tagline: "For freelancers",
            monthlyPrice: "$4.99", yearlyPrice: "$49.99",
            color: Color.blue,
            features: [
                TierFeature(name: "10 invoices / month", included: true),
                TierFeature(name: "Unlimited items", included: true),
                TierFeature(name: "1 business profiles", included: true),
                TierFeature(name: "Unlimited Clients", included: true),
                TierFeature(name: "All templates", included: true),
                TierFeature(name: "Revenue analytics", included: true),
            ],
            ctaText: "Start Free Trial",
            isFree: false
        ),
        TierInfo(
            name: "Pro", tagline: "For growing businesses",
            monthlyPrice: "$7.99", yearlyPrice: "$79.99",
            color: Color.purple,
            features: [
                TierFeature(name: "50 invoices / month", included: true),
                TierFeature(name: "Unlimited items", included: true),
                TierFeature(name: "3 business profiles", included: true),
                TierFeature(name: "Unlimited Clients", included: true),
                TierFeature(name: "All templates", included: true),
                TierFeature(name: "Revenue analytics", included: true),
            ],
            ctaText: "Start Free Trial",
            isFree: false
        ),
        TierInfo(
            name: "Business", tagline: "For teams & agencies",
            monthlyPrice: "$19.99", yearlyPrice: "$199.99",
            color: Color.orange,
            features: [
                TierFeature(name: "Unlimited invoices", included: true),
                TierFeature(name: "Unlimited items", included: true),
                TierFeature(name: "10 business profiles", included: true),
                TierFeature(name: "Unlimited Clients", included: true),
                TierFeature(name: "All templates", included: true),
                TierFeature(name: "Revenue analytics", included: true),
                TierFeature(name: "Priority support", included: true),
            ],
            ctaText: "Start Free Trial",
            isFree: false
        ),
    ]

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    tiers[selectedTier].color.opacity(0.15),
                    Color(.systemBackground),
                    tiers[selectedTier].color.opacity(0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: selectedTier)

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .background(Color(.systemGray5).opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Header
                VStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(tiers[selectedTier].color)
                        .animation(.easeInOut, value: selectedTier)
                    Text("Invoicor")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Choose your plan")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
                .padding(.bottom, 16)

                // Billing toggle
                Picker("Billing", selection: $billingCycle) {
                    Text("Monthly").tag(0)
                    Text("Yearly · Save 17%").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)

                // Swipeable tier cards
                TabView(selection: $selectedTier) {
                    ForEach(Array(tiers.enumerated()), id: \.offset) { index, tier in
                        tierCard(tier: tier, index: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxHeight: .infinity)

                // CTA Button
                VStack(spacing: 12) {
                    let tier = tiers[selectedTier]

                    Button {
                        // TODO: RevenueCat purchase
                    } label: {
                        Text(tier.isFree ? "Current Plan" : tier.ctaText)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                tier.isFree
                                    ? AnyShapeStyle(Color.gray)
                                    : AnyShapeStyle(
                                        LinearGradient(
                                            colors: [tier.color, tier.color.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(tier.isFree)
                    .padding(.horizontal, 20)

                    // Price label
                    if !tier.isFree {
                        Text("then \(billingCycle == 0 ? tier.monthlyPrice + "/mo" : tier.yearlyPrice + "/yr") · Cancel anytime")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Restore + Legal
                    Button("Restore Purchases") {
                        // TODO: RevenueCat restore
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text("[Terms of Service](https://invoicor.com/terms) · [Privacy Policy](https://invoicor.com/privacy)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .tint(.secondary)
                        .padding(.bottom, 8)
                }
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Tier Card

    private func tierCard(tier: TierInfo, index: Int) -> some View {
        VStack(spacing: 0) {
            // Tier header
            VStack(spacing: 4) {
                Text(tier.name)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(tier.tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Price
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(billingCycle == 0 ? tier.monthlyPrice : tier.yearlyPrice)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(tier.color)
                    if !tier.isFree {
                        Text(billingCycle == 0 ? "/mo" : "/yr")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)

                if billingCycle == 1 && !tier.isFree {
                    Text("billed annually")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Divider
            Rectangle()
                .fill(tier.color.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 20)

            // Features list
            VStack(alignment: .leading, spacing: 10) {
                ForEach(tier.features) { feature in
                    HStack(spacing: 10) {
                        Image(systemName: feature.included ? "checkmark.circle.fill" : "minus.circle")
                            .font(.subheadline)
                            .foregroundStyle(feature.included ? tier.color : Color(.systemGray4))
                        Text(feature.name)
                            .font(.subheadline)
                            .foregroundStyle(feature.included ? .primary : .tertiary)
                    }
                }
            }
            .padding(20)

            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: selectedTier == index ? tier.color.opacity(0.15) : .clear, radius: 12, y: 4)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    selectedTier == index ? tier.color.opacity(0.3) : Color(.systemGray5),
                    lineWidth: selectedTier == index ? 2 : 1
                )
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}

// MARK: - Data Models

private struct TierInfo {
    let name: String
    let tagline: String
    let monthlyPrice: String
    let yearlyPrice: String
    let color: Color
    let features: [TierFeature]
    let ctaText: String
    let isFree: Bool
}

private struct TierFeature: Identifiable {
    let id = UUID()
    let name: String
    let included: Bool
}
