// =================================================================
// FILE: Screens/Onboarding/OnboardingFlow.swift
// =================================================================
import SwiftUI

// MARK: - Brand Colors
private extension Color {
    static let brandBlue = Color(red: 0.23, green: 0.51, blue: 0.96)
    static let brandIndigo = Color(red: 0.35, green: 0.34, blue: 0.84)
}

// MARK: - Locale Currency Helper
private struct LocaleInvoice {
    static var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    static func format(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    static var sampleItems: [(String, String)] {
        return [
            ("Bathroom renovation", format(1850.00)),
            ("Kitchen fitting", format(2400.00)),
            ("Boiler service", format(350.00)),
        ]
    }

    static var sampleTotal: String {
        format(4600.00)
    }
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

                TabView(selection: $step) {
                    ValueScreen {
                        ob.trackStep("value_seen")
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

// MARK: - Screen 1: Value Showcase
private struct ValueScreen: View {
    let onContinue: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Speed claim
            VStack(spacing: 4) {
                Text("Send professional invoices")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.primary)

                Text("and get paid faster")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.brandBlue, Color.brandIndigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .multilineTextAlignment(.center)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .padding(.bottom, 24)

            // Invoice preview card (locale currency)
            InvoicePreviewCard()
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.9)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            // Proof points (outcomes not features)
            VStack(spacing: 12) {
                ProofRow(
                    icon: "clock.fill",
                    color: .orange,
                    text: "Stop formatting in Word, Docs, or Excel"
                )
                ProofRow(
                    icon: "globe",
                    color: .blue,
                    text: "Multi currencies. 6+ languages. Your client reads it in theirs"
                )
                ProofRow(
                    icon: "arrow.counterclockwise",
                    color: .green,
                    text: "Reuse clients and products. Repeating invoice takes seconds"
                )
                ProofRow(
                    icon: "doc.richtext.fill",
                    color: .purple,
                    text: "30+ templates. Add your logo. Look professional instantly"
                )
            }
            .padding(.horizontal, 28)
            .opacity(appeared ? 1 : 0)

            Spacer()

            // CTA
            Button(action: onContinue) {
                Text("See how it works")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        LinearGradient(
                            colors: [Color.brandBlue, Color.brandIndigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.brandBlue.opacity(0.3), radius: 16, y: 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7)) { appeared = true }
        }
    }
}

// MARK: - Invoice Preview Card
private struct InvoicePreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("INVOICE")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(Color.brandBlue)
                    Text("INV-00047")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Fake logo
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.brandBlue.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.brandBlue)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 12)

            // Line items (locale currency)
            VStack(spacing: 6) {
                ForEach(LocaleInvoice.sampleItems, id: \.0) { item in
                    InvoiceLineRow(item: item.0, amount: item.1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().padding(.horizontal, 12)

            // Total
            HStack {
                Text("Total")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text(LocaleInvoice.sampleTotal)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color.brandBlue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Status badge
            HStack {
                Spacer()
                Text("SENT")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(.bottom, 10)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator).opacity(0.2))
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

private struct InvoiceLineRow: View {
    let item: String
    let amount: String

    var body: some View {
        HStack {
            Text(item)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            Text(amount)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Proof Row
private struct ProofRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

// MARK: - Screen 2: Start Free
private struct StartFreeScreen: View {
    let onGetStarted: () -> Void
    @State private var showRegister = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Badge
            Text("3 FREE INVOICES")
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
            Text("Create your first invoice")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 8)

            Text("No card needed. Takes about a minute.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 32)

            // What you get
            VStack(spacing: 14) {
                TrustRow(
                    icon: "checkmark.seal.fill",
                    color: .blue,
                    text: "30+ professional templates with your logo"
                )
                TrustRow(
                    icon: "function",
                    color: .orange,
                    text: "Tax, discounts, and totals auto-calculated"
                )
                TrustRow(
                    icon: "square.and.arrow.up.fill",
                    color: .purple,
                    text: "Export PDF or share via any app"
                )
                TrustRow(
                    icon: "chart.bar.fill",
                    color: .green,
                    text: "Track sent, draft, and paid invoices"
                )
                TrustRow(
                    icon: "lock.shield.fill",
                    color: .gray,
                    text: "GDPR compliant. Data in Europe. No ads."
                )
            }
            .padding(.horizontal, 28)
            .opacity(appeared ? 1 : 0)

            Spacer()

            // CTA
            VStack(spacing: 12) {
                Button {
                    onGetStarted()
                    showRegister = true
                } label: {
                    Text("Create my first invoice")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(
                                colors: [Color.brandBlue, Color.brandIndigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.brandBlue.opacity(0.3), radius: 16, y: 6)
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
        }
    }
}

// MARK: - Trust Row
private struct TrustRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}
