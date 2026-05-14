// =================================================================
// FILE: Screens/Onboarding/OnboardingFlow.swift
// =================================================================
// Polished onboarding: animated, gradient-rich, dark premium feel.
// Brand colors: #FE8C00 → #F83600 (orange gradient from icon)

import SwiftUI

// MARK: - Brand Colors

private extension Color {
    static let brandOrange = Color(red: 0.996, green: 0.549, blue: 0)
    static let brandRed = Color(red: 0.973, green: 0.212, blue: 0)
}

// MARK: - Ambient Background (reused across screens)

private struct AmbientBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Color(.systemBackground)

            // Floating warm orb - top right
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.brandOrange.opacity(0.1), .clear],
                        center: .center, startRadius: 20, endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 120 + sin(phase * 0.7) * 30, y: -200 + cos(phase * 0.5) * 20)

            // Floating indigo orb - bottom left
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.indigo.opacity(0.07), .clear],
                        center: .center, startRadius: 20, endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: -140 + cos(phase * 0.6) * 25, y: 280 + sin(phase * 0.8) * 15)

            // Subtle red accent - center right
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.brandRed.opacity(0.04), .clear],
                        center: .center, startRadius: 10, endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: 80 + sin(phase * 0.9) * 20, y: 50 + cos(phase * 0.4) * 30)
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

    private var totalSteps: Int {
        ob.selectedICP == "exploring" ? 4 : 5
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 0) {
                // Top bar: progress dots + login
                HStack(spacing: 0) {
                    HStack(spacing: 8) {
                        ForEach(0..<totalSteps, id: \.self) { i in
                            Capsule()
                                .fill(
                                    i < step ? LinearGradient(colors: [.brandOrange, .brandRed], startPoint: .leading, endPoint: .trailing)
                                    : i == step ? LinearGradient(colors: [.brandOrange, .brandRed], startPoint: .leading, endPoint: .trailing)
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
                        next()
                    }.tag(0)

                    if ob.selectedICP != "exploring" {
                        PainScreen(icp: ob.selectedICP) {
                            ob.trackStep("pain_viewed"); next()
                        }.tag(1)
                        SolutionScreen(icp: ob.selectedICP) {
                            ob.trackStep("solution_viewed"); next()
                        }.tag(2)
                        TemplatesScreen {
                            ob.trackStep("templates_viewed"); next()
                        }.tag(3)
                        PlanScreen {
                            ob.trackStep("plan_viewed", planViewed: "free")
                        }.tag(4)
                    } else {
                        SolutionScreen(icp: "exploring") {
                            ob.trackStep("solution_viewed"); next()
                        }.tag(1)
                        TemplatesScreen {
                            ob.trackStep("templates_viewed"); next()
                        }.tag(2)
                        PlanScreen {
                            ob.trackStep("plan_viewed", planViewed: "free")
                        }.tag(3)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: step)
            }
        }
        .sheet(isPresented: $showLogin) { LoginScreen() }
        .task { await ob.fetchConfig() }
    }

    private func next() { if step < totalSteps - 1 { withAnimation { step += 1 } } }
}

// MARK: - Gradient CTA Button

private struct GradientCTA: View {
    let title: String
    let action: () -> Void
    @State private var shimmer = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    ZStack {
                        LinearGradient(
                            colors: [.brandOrange, .brandRed],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        // Shimmer effect
                        LinearGradient(
                            colors: [.clear, Color(.systemGray5), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .offset(x: shimmer ? 300 : -300)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .brandOrange.opacity(0.3), radius: 16, y: 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false).delay(1)) {
                shimmer = true
            }
        }
    }
}

// MARK: - Screen 1: ICP Selection

private struct ICPScreen: View {
    let onSelect: (String) -> Void
    private let ob = OnboardingManager.shared
    @State private var appeared = false
    @State private var iconPulse = false

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

            // App logo with animated glow
            ZStack {
                // Pulsing glow ring
                Circle()
                    .stroke(
                        LinearGradient(colors: [.brandOrange.opacity(0.3), .brandRed.opacity(0.1)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2
                    )
                    .frame(width: 110, height: 110)
                    .scaleEffect(iconPulse ? 1.15 : 1)
                    .opacity(iconPulse ? 0 : 0.6)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.brandOrange.opacity(0.12), .clear],
                            center: .center, startRadius: 10, endRadius: 55
                        )
                    )
                    .frame(width: 100, height: 100)

                // YOUR app icon from Assets
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .brandOrange.opacity(0.4), radius: 12, y: 4)
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
                            Image(systemName: "arrow.right")
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

            Spacer(); Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.7)) { appeared = true }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                iconPulse = true
            }
        }
    }
}

// MARK: - Screen 2: Pain Points

private struct PainScreen: View {
    let icp: String
    let onNext: () -> Void
    private let ob = OnboardingManager.shared
    @State private var appeared = false
    @State private var activePoint = -1

    private var content: OnboardingContent? {
        ob.config?.screens.first(where: { $0.id == "pain" })?.content?[icp]
    }
    private var headline: String { content?.headline ?? "Sound familiar?" }
    private var points: [OnboardingPoint] {
        content?.points ?? [
            OnboardingPoint(icon: nil, text: "Creating invoices takes too long."),
            OnboardingPoint(icon: nil, text: "Your invoices don't look professional."),
            OnboardingPoint(icon: nil, text: "You lose track of who paid."),
        ]
    }

    // SF Symbols instead of emojis (no rendering issues)
    private let icons = ["clock.badge.exclamationmark", "doc.questionmark", "banknote"]
    private let iconColors: [Color] = [.orange, .red, .yellow]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(headline)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 16) {
                ForEach(Array(points.enumerated()), id: \.offset) { i, point in
                    HStack(alignment: .top, spacing: 14) {
                        // Animated icon circle
                        ZStack {
                            Circle()
                                .fill(
                                    activePoint >= i
                                    ? (iconColors[i % iconColors.count]).opacity(0.12)
                                    : Color(.systemGray6)
                                )
                                .frame(width: 48, height: 48)

                            Image(systemName: i < icons.count ? icons[i] : "exclamationmark.circle")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(
                                    activePoint >= i
                                    ? iconColors[i % iconColors.count]
                                    : Color(.systemBackground)
                                )
                        }
                        .scaleEffect(activePoint >= i ? 1 : 0.7)

                        Text(point.text)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(activePoint >= i ? .primary : .quaternary)
                            .lineSpacing(5)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .animation(.spring(response: 0.5).delay(Double(i) * 0.15), value: activePoint)
                }
            }

            Spacer()
            GradientCTA(title: "That's me", action: onNext)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5)) { appeared = true }
            for i in points.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.6) {
                    withAnimation { activePoint = i }
                }
            }
        }
    }
}

// MARK: - Screen 3: Solution

private struct SolutionScreen: View {
    let icp: String
    let onNext: () -> Void
    private let ob = OnboardingManager.shared
    @State private var appeared = false

    private var content: OnboardingContent? {
        ob.config?.screens.first(where: { $0.id == "solution" })?.content?[icp]
    }
    private var headline: String { content?.headline ?? "The fastest way to invoice" }
    private var points: [OnboardingPoint] {
        content?.points ?? [
            OnboardingPoint(icon: "bolt", text: "Pick template, add client, tap send. 10 seconds."),
            OnboardingPoint(icon: "gift", text: "3 invoices free. No watermarks."),
        ]
    }

    private let cardColors: [Color] = [.indigo, .blue, .green]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(headline)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [.primary],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 14) {
                ForEach(Array(points.enumerated()), id: \.offset) { i, point in
                    let color = cardColors[i % cardColors.count]

                    HStack(alignment: .top, spacing: 14) {
                        if let icon = point.icon, !icon.isEmpty {
                            ZStack {
                                Circle()
                                    .fill(color.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                Image(systemName: icon)
                                    .font(.title3)
                                    .foregroundStyle(color)
                            }
                        }
                        Text(point.text)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.8))
                            .lineSpacing(5)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(color.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.1)))
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : 40)
                    .animation(.spring(response: 0.6).delay(Double(i) * 0.12), value: appeared)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            GradientCTA(title: "Show me", action: onNext)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appeared = true }
        }
    }
}

// MARK: - Screen 4: Templates

private struct TemplatesScreen: View {
    let onNext: () -> Void
    private let ob = OnboardingManager.shared
    @State private var appeared = false
    @State private var autoScroll: CGFloat = 0

    private var screen: OnboardingScreenConfig? {
        ob.config?.screens.first(where: { $0.id == "templates" })
    }

    private let templates: [(String, Color, Bool)] = [
        ("Modern", .indigo, false),
        ("Classic", .blue, false),
        ("Bold", .teal, false),
        ("Minimal", .purple, true),
        ("Creative", .orange, true),
        ("Elegant", .pink, false),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(screen?.headline ?? "Your invoices will look like this")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
                .opacity(appeared ? 1 : 0)

            Text(screen?.subtext ?? "30+ templates included. Pick your style later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .opacity(appeared ? 1 : 0)

            // Template carousel with floating animation
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(templates.enumerated()), id: \.offset) { i, tmpl in
                        OnboardingTemplateCard(
                            name: tmpl.0,
                            color: tmpl.1,
                            isPro: tmpl.2,
                            index: i
                        )
                        .scaleEffect(appeared ? 1 : 0.8)
                        .opacity(appeared ? 1 : 0)
                        .rotation3DEffect(
                            .degrees(appeared ? 0 : 20),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .animation(
                            .spring(response: 0.7, dampingFraction: 0.7)
                            .delay(Double(i) * 0.1),
                            value: appeared
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }

            Spacer()
            GradientCTA(title: "I want these", action: onNext)
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }
}

private struct OnboardingTemplateCard: View {
    let name: String
    let color: Color
    let isPro: Bool
    let index: Int
    @State private var floating = false
    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Animated glow behind card
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(glowPulse ? 0.12 : 0.05))
                    .frame(width: 150, height: 204)
                    .blur(radius: 12)
                    .offset(y: 6)

                // Invoice card
                RoundedRectangle(cornerRadius: 10)
                    .fill(.primary)
                    .frame(width: 140, height: 192)
                    .overlay(
                        VStack(alignment: .leading, spacing: 0) {
                            // Gradient colored header
                            LinearGradient(
                                colors: [color, color.opacity(0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            .frame(height: 38)
                            .overlay(
                                HStack {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.4))
                                        .frame(width: 40, height: 6)
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(.tertiary)
                                        .frame(width: 25, height: 6)
                                }
                                .padding(.horizontal, 10)
                            )
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10))

                            VStack(alignment: .leading, spacing: 5) {
                                // Company name
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.18))
                                    .frame(width: 65, height: 7)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 45, height: 5)

                                Spacer().frame(height: 6)

                                // Line items with subtle color
                                ForEach(0..<3, id: \.self) { row in
                                    HStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.gray.opacity(0.08))
                                            .frame(height: 5)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(color.opacity(0.1))
                                            .frame(width: 28, height: 5)
                                    }
                                }

                                // Divider line
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 0.5)
                                    .padding(.vertical, 4)

                                // Total
                                HStack {
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 3) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(color.opacity(0.15))
                                            .frame(width: 35, height: 4)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(color.opacity(0.5))
                                            .frame(width: 50, height: 9)
                                    }
                                }
                            }
                            .padding(10)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: color.opacity(0.12), radius: 10, y: 6)
            }
            .offset(y: floating ? -6 : 6)
            .animation(
                .easeInOut(duration: 2.2 + Double(index) * 0.4)
                .repeatForever(autoreverses: true),
                value: floating
            )

            Text(name)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.top, 10)

            if isPro {
                Text("PRO")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.purple.opacity(0.12))
                    .clipShape(Capsule())
                    .padding(.top, 4)
            }
        }
        .onAppear {
            floating = true
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

// MARK: - Screen 5: Plan

private struct PlanScreen: View {
    let onGetStarted: () -> Void
    @State private var showRegister = false
    @State private var appeared = false
    @State private var checkmarks: Int = -1
    @State private var iconBounce = false
    private let ob = OnboardingManager.shared

    private var screen: OnboardingScreenConfig? {
        ob.config?.screens.first(where: { $0.id == "plan" })
    }
    private var features: [String] {
        screen?.freeFeatures ?? [
            "3 invoices", "All standard templates", "Multi-currency",
            "PDF export and sharing", "Saved clients and products",
        ]
    }

    private let featureIcons = [
        "doc.text", "paintpalette", "globe.americas",
        "square.and.arrow.up", "person.2"
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon with animated glow
            ZStack {
                // Pulsing glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.green.opacity(0.15), .clear],
                            center: .center, startRadius: 10, endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(iconBounce ? 1.15 : 1)

                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .brandOrange.opacity(0.3), radius: 12, y: 4)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
            }
            .padding(.bottom, 20)

            Text(screen?.headline ?? "3 invoices on us")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)

            Text(screen?.subtext ?? "Start free. Upgrade when you need more.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .padding(.bottom, 32)
                .opacity(appeared ? 1 : 0)

            // Feature checklist with icons
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(features.enumerated()), id: \.offset) { i, f in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    checkmarks >= i
                                    ? Color.green.opacity(0.12)
                                    : Color(.systemGray6)
                                )
                                .frame(width: 36, height: 36)

                            Image(systemName: checkmarks >= i
                                  ? "checkmark"
                                  : (i < featureIcons.count ? featureIcons[i] : "circle"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(
                                    checkmarks >= i
                                    ? .green
                                    : Color(.white.opacity(0.15))
                                )
                        }
                        .scaleEffect(checkmarks == i ? 1.15 : 1)

                        Text(f)
                            .font(.body.weight(.medium))
                            .foregroundStyle(
                                checkmarks >= i
                                ? .primary
                                : .quaternary
                            )
                    }
                    .animation(.spring(response: 0.35).delay(Double(i) * 0.08), value: checkmarks)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)

            Text(screen?.upgradeText ?? "Need more than 3? Plans start at $4.99/mo")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    onGetStarted()
                    showRegister = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                        Text(screen?.ctaPrimary ?? "Get Started Free")
                            .font(.body.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        LinearGradient(
                            colors: [.brandOrange, .brandRed],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .brandOrange.opacity(0.35), radius: 16, y: 6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .sheet(isPresented: $showRegister) { RegisterScreen() }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appeared = true }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                iconBounce = true
            }
            for i in features.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.2) {
                    withAnimation { checkmarks = i }
                }
            }
        }
    }
}
