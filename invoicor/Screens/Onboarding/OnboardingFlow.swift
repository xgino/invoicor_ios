// =================================================================
// FILE: Screens/Onboarding/OnboardingFlow.swift
// =================================================================
// Simplified 2-screen onboarding: ICP question → Start Free
// Removed: Pain, Solution, Templates, Pricing screens
// Why: 36% of users dropped at pricing screen. 82% total drop-off.

import SwiftUI

// MARK: - Brand Colors
private extension Color {
    static let brandBlue = Color(red: 0.23, green: 0.51, blue: 0.96)
    static let brandIndigo = Color(red: 0.35, green: 0.34, blue: 0.84)
}

// MARK: - Ambient Background
private struct AmbientBackground: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        ZStack {
            Color(.systemBackground)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.brandBlue.opacity(0.08), .clear],
                        center: .center, startRadius: 20, endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 120 + sin(phase * 0.7) * 30, y: -200 + cos(phase * 0.5) * 20)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.brandIndigo.opacity(0.06), .clear],
                        center: .center, startRadius: 20, endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: -140 + cos(phase * 0.6) * 25, y: 280 + sin(phase * 0.8) * 15)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Flow Container
struct OnboardingFlow: View {
    @State private var step = 0
    @State private var showLogin = false
    private let ob = OnboardingManager.shared

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 0) {
                // Top bar: dots + login
                HStack(spacing: 0) {
                    HStack(spacing: 8) {
                        ForEach(0..<2, id: \.self) { i in
                            Capsule()
                                .fill(
                                    i <= step
                                    ? LinearGradient(colors: [.brandBlue, .brandIndigo], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.primary.opacity(0.12), Color.primary.opacity(0.12)], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: i == step ? 28 : 8, height: 8)
                                .animation(.spring(response: 0.4), value: step)
                        }
                    }

                    Spacer()

                    Button("Log in") { showLogin = true }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Screens
                TabView(selection: $step) {
                    ICPScreen { icp in
                        ob.trackStep("icp_selected", icp: icp)
                        withAnimation { step = 1 }
                    }.tag(0)

                    StartFreeScreen {
                        ob.trackStep("registered")
                    }.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: step)
            }
        }
        .sheet(isPresented: $showLogin) { LoginScreen() }
        .task { await ob.fetchConfig() }
    }
}

// MARK: - Screen 1: ICP Selection
private struct ICPScreen: View {
    let onSelect: (String) -> Void
    private let ob = OnboardingManager.shared
    @State private var appeared = false

    private var options: [OnboardingOption] {
        ob.config?.screens.first(where: { $0.id == "icp_select" })?.options ?? [
            OnboardingOption(key: "trades", title: "I do jobs for clients", subtitle: "Plumbing, electrical, cleaning, painting", icon: "wrench.and.screwdriver"),
            OnboardingOption(key: "freelance", title: "I freelance or consult", subtitle: "Design, dev, writing, photography", icon: "laptopcomputer"),
            OnboardingOption(key: "business", title: "I run a small business", subtitle: "Agency, studio, practice", icon: "building.2"),
            OnboardingOption(key: "exploring", title: "Just checking it out", subtitle: "", icon: "sparkles"),
        ]
    }

    private let iconColors: [String: Color] = [
        "trades": .orange,
        "freelance": .indigo,
        "business": .blue,
        "exploring": .purple,
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App logo
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.brandBlue.opacity(0.12), .clear],
                            center: .center, startRadius: 10, endRadius: 55
                        )
                    )
                    .frame(width: 100, height: 100)

                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .brandBlue.opacity(0.3), radius: 12, y: 4)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
            }
            .padding(.bottom, 24)

            Text(ob.config?.screens.first(where: { $0.id == "icp_select" })?.headline
                 ?? "What do you need invoices for?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.element.key) { index, opt in
                    Button { onSelect(opt.key) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: opt.icon)
                                .font(.title3)
                                .foregroundStyle(iconColors[opt.key] ?? .primary)
                                .frame(width: 42, height: 42)
                                .background((iconColors[opt.key] ?? .primary).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(opt.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if !opt.subtitle.isEmpty {
                                    Text(opt.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator).opacity(0.3)))
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.08), value: appeared)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.7)) { appeared = true }
        }
    }
}

// MARK: - Screen 2: Start Free
private struct StartFreeScreen: View {
    let onGetStarted: () -> Void
    @State private var showRegister = false
    @State private var appeared = false
    @State private var checkmarks: Int = -1

    private let features: [(String, String)] = [
        ("doc.text.fill", "Professional templates"),
        ("dollarsign.circle.fill", "Multi-currency support"),
        ("square.and.arrow.up.fill", "PDF export and sharing"),
        ("person.2.fill", "Saved clients and products"),
        ("bolt.fill", "Create an invoice in 30 seconds"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Badge
            Text("3 INVOICES ON US")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(Color.brandBlue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.brandBlue.opacity(0.1))
                .clipShape(Capsule())
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 20)

            // Headline
            Text("Start free")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
                .opacity(appeared ? 1 : 0)

            Text("No card needed. No time limit.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .padding(.bottom, 36)
                .opacity(appeared ? 1 : 0)

            // Feature checklist
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(features.enumerated()), id: \.offset) { i, feature in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    checkmarks >= i
                                    ? Color.blue.opacity(0.1)
                                    : Color(.systemGray6)
                                )
                                .frame(width: 36, height: 36)

                            Image(systemName: checkmarks >= i ? "checkmark" : feature.0)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(
                                    checkmarks >= i
                                    ? .blue
                                    : Color(.systemGray4)
                                )
                        }
                        .scaleEffect(checkmarks == i ? 1.15 : 1)

                        Text(feature.1)
                            .font(.body.weight(.medium))
                            .foregroundStyle(
                                checkmarks >= i ? .primary : .quaternary
                            )
                    }
                    .animation(.spring(response: 0.35).delay(Double(i) * 0.08), value: checkmarks)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // CTA
            VStack(spacing: 12) {
                Button {
                    onGetStarted()
                    showRegister = true
                } label: {
                    Text("Start Free")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(
                                colors: [.brandBlue, .brandIndigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .brandBlue.opacity(0.3), radius: 16, y: 6)
                }

                Button {
                    showRegister = true
                } label: {
                    Text("Already have an account? **Log in**")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .sheet(isPresented: $showRegister) { RegisterScreen() }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appeared = true }
            for i in features.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.2) {
                    withAnimation { checkmarks = i }
                }
            }
        }
    }
}
