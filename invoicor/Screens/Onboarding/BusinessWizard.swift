// =================================================================
// FILE: Screens/Onboarding/BusinessWizard.swift
// =================================================================

import SwiftUI

struct BusinessWizard: View {
    @State private var step = 0
    @State private var bgPhase: CGFloat = 0
    @State private var showSuccess = false

    // Step 1
    @State private var companyName = ""
    @State private var fullName = ""

    // Step 2
    @State private var addressLine1 = ""
    @State private var city = ""
    @State private var postalCode = ""
    @State private var country = ""
    @State private var email = ""

    // Step 3
    @State private var currency = "USD"
    @State private var taxRate = ""
    @State private var paymentTerms = "Net 30"

    @State private var isSaving = false
    @State private var errorMessage = ""

    private let totalSteps = 3

    var body: some View {
        ZStack {
            // Adaptive ambient background
            ZStack {
                Color(.systemBackground)
                
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.indigo.opacity(0.09), .clear],
                        center: .center, startRadius: 20, endRadius: 200
                    ))
                    .frame(width: 400, height: 400)
                    .offset(x: -100 + sin(bgPhase * 0.6) * 30, y: -250 + cos(bgPhase * 0.4) * 20)

                Circle()
                    .fill(RadialGradient(
                        colors: [Color.wBrandOrange.opacity(0.06), .clear],
                        center: .center, startRadius: 10, endRadius: 180
                    ))
                    .frame(width: 360, height: 360)
                    .offset(x: 120 + cos(bgPhase * 0.5) * 25, y: 300 + sin(bgPhase * 0.7) * 15)

                Circle()
                    .fill(RadialGradient(
                        colors: [Color.green.opacity(0.04), .clear],
                        center: .center, startRadius: 10, endRadius: 150
                    ))
                    .frame(width: 300, height: 300)
                    .offset(x: 60 + sin(bgPhase * 0.8) * 20, y: 80 + cos(bgPhase * 0.3) * 25)
            }
            .ignoresSafeArea()
            // Allow user to tap anywhere on the background to hide the keyboard
            .onTapGesture {
                hideKeyboard()
            }

            if showSuccess {
                // Success animation before transitioning to main app
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 100, height: 100)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.green)
                    }
                    Text("You're all set!")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Let's create your first invoice")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: 0) {
                    // Progress
                    HStack(spacing: 0) {
                        HStack(spacing: 8) {
                            ForEach(0..<totalSteps, id: \.self) { i in
                                Capsule()
                                    .fill(
                                        i <= step
                                        ? LinearGradient(colors: [.wBrandOrange, .wBrandRed], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [Color.primary.opacity(0.1), Color.primary.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: i == step ? 28 : 8, height: 8)
                                    .animation(.spring(response: 0.4), value: step)
                            }
                        }
                        Spacer()
                        Text("\(step + 1) of \(totalSteps)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                    TabView(selection: $step) {
                        WizardStepOne(
                            companyName: $companyName,
                            fullName: $fullName,
                            onNext: {
                                hideKeyboard() // Dismiss keyboard when continuing
                                withAnimation(.easeInOut(duration: 0.35)) { step = 1 }
                            }
                        ).tag(0)

                        WizardStepTwo(
                            addressLine1: $addressLine1,
                            city: $city,
                            postalCode: $postalCode,
                            country: $country,
                            email: $email,
                            onNext: {
                                hideKeyboard() // Dismiss keyboard when continuing
                                withAnimation(.easeInOut(duration: 0.35)) { step = 2 }
                            }
                        ).tag(1)

                        WizardStepThree(
                            currency: $currency,
                            taxRate: $taxRate,
                            paymentTerms: $paymentTerms,
                            isSaving: $isSaving,
                            errorMessage: $errorMessage,
                            onSave: {
                                hideKeyboard() // Dismiss keyboard before saving
                                await saveAndFinish()
                            }
                        ).tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.35), value: step)
                }
            }
        }
        .onAppear {
            currency = Locale.current.currency?.identifier ?? "USD"
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                bgPhase = .pi * 2
            }
        }
    }

    // MARK: - Save

    private func saveAndFinish() async {
        isSaving = true
        errorMessage = ""

        let name = companyName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            errorMessage = "Company name is required"
            isSaving = false
            return
        }

        // Map payment terms to due days and display text
        let dueDays: Int
        let termsText: String
        switch paymentTerms {
        case "Net 15":
            dueDays = 15
            termsText = "Payment due within 15 days of invoice date"
        case "Net 30":
            dueDays = 30
            termsText = "Payment due within 30 days of invoice date"
        case "Net 60":
            dueDays = 60
            termsText = "Payment due within 60 days of invoice date"
        case "Due on Receipt":
            dueDays = 0
            termsText = "Payment due upon receipt of this invoice"
        case "14 Days":
            dueDays = 14
            termsText = "Please remit payment within 14 days"
        default:
            dueDays = 30
            termsText = "Payment due within 30 days of invoice date"
        }

        var body: [String: Any] = [
            "company_name": name,
            "default_currency": currency,
            "default_tax_rate": taxRate.isEmpty ? "0" : taxRate,
            "default_payment_terms": termsText,
            "default_due_days": dueDays,
        ]
        if !addressLine1.isEmpty { body["address_line_1"] = addressLine1 }
        if !city.isEmpty { body["city"] = city }
        if !postalCode.isEmpty { body["postal_code"] = postalCode }
        if !country.isEmpty { body["country"] = country }
        if !email.isEmpty { body["email"] = email }

        do {
            let profiles = try await APIClient.shared.request(
                [BusinessProfile].self, method: "GET", path: "/accounts/business-profiles/"
            )
            if let existing = profiles.first {
                _ = try await APIClient.shared.request(
                    BusinessProfile.self, method: "PUT",
                    path: "/accounts/business-profiles/\(existing.publicId)/", body: body
                )
            } else {
                _ = try await APIClient.shared.request(
                    BusinessProfile.self, method: "POST",
                    path: "/accounts/business-profiles/", body: body
                )
            }

            // Show success animation
            await MainActor.run {
                isSaving = false
                withAnimation(.spring(response: 0.5)) { showSuccess = true }
            }

            // Wait for animation, then complete
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            // REPLACE THE OLD COMPLETION LOGIC WITH THIS:
            await AuthManager.shared.refreshMe()
            
            await MainActor.run {
                // This triggers RootView to transition to MainTabView
                AuthManager.shared.hasBusinessProfile = true
            }

        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Failed to save"
                isSaving = false
            }
        }
    }
}

// MARK: - Brand Colors

private extension Color {
    static let wBrandOrange = Color(red: 0.996, green: 0.549, blue: 0)
    static let wBrandRed = Color(red: 0.973, green: 0.212, blue: 0)
}

// MARK: - Step 1: Your Business

private struct WizardStepOne: View {
    @Binding var companyName: String
    @Binding var fullName: String
    let onNext: () -> Void
    @State private var appeared = false
    @State private var iconFloat = false
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.indigo.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 90, height: 90)
                    .scaleEffect(iconFloat ? 1.08 : 0.95)
                Circle()
                    .fill(Color.indigo.opacity(0.08))
                    .frame(width: 76, height: 76)
                Image(systemName: "building.2.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        LinearGradient(colors: [.indigo, .indigo.opacity(0.6)],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }
            .offset(y: iconFloat ? -4 : 4)
            .padding(.bottom, 24)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.7)

            Text("What's your business called?")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 6)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

            Text("This appears at the top of every invoice")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 16) {
                WizardInput(
                    icon: "briefcase", iconColor: .indigo,
                    label: "Company or Business Name",
                    text: $companyName, placeholder: "e.g. Studio Nova"
                )
                .focused($nameFieldFocused)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.6).delay(0.15), value: appeared)

                WizardInput(
                    icon: "person", iconColor: .indigo.opacity(0.6),
                    label: "Your Name",
                    text: $fullName, placeholder: "e.g. Alex Johnson",
                    optional: true
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.6).delay(0.25), value: appeared)
            }
            .padding(.horizontal, 24)

            Spacer(); Spacer()

            WizardGradientCTA(
                title: "Continue",
                disabled: companyName.trimmingCharacters(in: .whitespaces).isEmpty
            ) { onNext() }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appeared = true }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { iconFloat = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { nameFieldFocused = true }
        }
    }
}

// MARK: - Step 2: Address + Email

private struct WizardStepTwo: View {
    @Binding var addressLine1: String
    @Binding var city: String
    @Binding var postalCode: String
    @Binding var country: String
    @Binding var email: String
    let onNext: () -> Void
    @State private var appeared = false
    @State private var iconFloat = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: 40)

                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 90, height: 90)
                        .scaleEffect(iconFloat ? 1.08 : 0.95)
                    Circle()
                        .fill(Color.blue.opacity(0.08))
                        .frame(width: 76, height: 76)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .blue.opacity(0.6)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                }
                .offset(y: iconFloat ? -4 : 4)
                .padding(.bottom, 24)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.7)

                Text("Where are you based?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 6)
                    .opacity(appeared ? 1 : 0)

                Text("Clients see this on your invoices")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 36)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 14) {
                    WizardInput(icon: "house", iconColor: .blue, label: "Street Address",
                                text: $addressLine1, placeholder: "e.g. 123 Main Street", optional: true)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.6).delay(0.1), value: appeared)

                    HStack(spacing: 12) {
                        WizardInput(icon: "building", iconColor: .blue, label: "City",
                                    text: $city, placeholder: "City", optional: true)
                        WizardInput(icon: "number", iconColor: .blue.opacity(0.6), label: "Postal",
                                    text: $postalCode, placeholder: "Code", optional: true)
                    }
                    .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.6).delay(0.2), value: appeared)

                    WizardInput(icon: "globe", iconColor: .blue, label: "Country",
                                text: $country, placeholder: "e.g. Netherlands", optional: true)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.6).delay(0.3), value: appeared)

                    // Email for invoices
                    WizardInput(icon: "envelope", iconColor: .blue, label: "Invoice Email",
                                text: $email, placeholder: "invoices@company.com",
                                optional: true, keyboard: .emailAddress)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.6).delay(0.4), value: appeared)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 40)

                VStack(spacing: 8) {
                    WizardGradientCTA(title: "Continue") { onNext() }
                    Button { onNext() } label: {
                        Text("Skip for now")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appeared = true }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { iconFloat = true }
        }
    }
}

// MARK: - Step 3: Defaults

private struct WizardStepThree: View {
    @Binding var currency: String
    @Binding var taxRate: String
    @Binding var paymentTerms: String
    @Binding var isSaving: Bool
    @Binding var errorMessage: String
    let onSave: () async -> Void
    @State private var appeared = false
    @State private var iconFloat = false

    private let currencies = ["USD", "EUR", "GBP", "CAD", "AUD", "CHF", "SEK", "NOK", "DKK", "PLN"]
    private let currencySymbols: [String: String] = [
        "USD": "$", "EUR": "€", "GBP": "£", "CAD": "C$", "AUD": "A$",
        "CHF": "Fr", "SEK": "kr", "NOK": "kr", "DKK": "kr", "PLN": "zł"
    ]

    // Payment terms with professional descriptions
    private let termOptions: [(key: String, label: String, desc: String)] = [
        ("Due on Receipt", "Immediate", "Pay upon receipt"),
        ("Net 15", "15 Days", "Due within 15 days"),
        ("Net 30", "30 Days", "Due within 30 days"),
        ("Net 60", "60 Days", "Due within 60 days"),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: 40)

                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 90, height: 90)
                        .scaleEffect(iconFloat ? 1.08 : 0.95)
                    Circle()
                        .fill(Color.green.opacity(0.08))
                        .frame(width: 76, height: 76)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(colors: [.green, .green.opacity(0.6)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                }
                .offset(y: iconFloat ? -4 : 4)
                .padding(.bottom, 24)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.7)

                Text("One last thing")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 6)
                    .opacity(appeared ? 1 : 0)

                Text("Set your defaults. Change anytime in settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)
                    .opacity(appeared ? 1 : 0)

                // Currency
                VStack(alignment: .leading, spacing: 10) {
                    Text("INVOICE CURRENCY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                        .padding(.horizontal, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(currencies.enumerated()), id: \.element) { i, code in
                                let isSelected = currency == code
                                let symbol = currencySymbols[code] ?? code
                                Button {
                                    withAnimation(.spring(response: 0.3)) { currency = code }
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(symbol)
                                            .font(.system(size: 18, weight: .bold))
                                            // Keep white when selected because the background is Indigo
                                            .foregroundStyle(isSelected ? .white : .primary)
                                        Text(code)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                                    }
                                    .frame(width: 56, height: 56)
                                    .background(
                                        isSelected
                                        ? LinearGradient(colors: [.indigo, .indigo.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [Color.primary.opacity(0.04), Color.primary.opacity(0.04)], startPoint: .top, endPoint: .bottom)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Color.indigo.opacity(0.5) : Color.primary.opacity(0.06)))
                                    .scaleEffect(isSelected ? 1.08 : 1)
                                    .shadow(color: isSelected ? .indigo.opacity(0.2) : .clear, radius: 8, y: 3)
                                }
                                .opacity(appeared ? 1 : 0)
                                .animation(.spring(response: 0.5).delay(Double(i) * 0.04), value: appeared)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 24)

                // Tax rate
                VStack(alignment: .leading, spacing: 10) {
                    Text("DEFAULT TAX RATE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    HStack(spacing: 10) {
                        ForEach(["0", "5", "10", "19", "21"], id: \.self) { rate in
                            let isSelected = taxRate == rate || (taxRate.isEmpty && rate == "0")
                            Button {
                                withAnimation(.spring(response: 0.3)) { taxRate = rate }
                            } label: {
                                Text("\(rate)%")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(isSelected ? Color.green : Color.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(isSelected ? Color.green.opacity(0.15) : Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.green.opacity(0.3) : Color.primary.opacity(0.06)))
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("Custom rate", text: $taxRate)
                            .font(.subheadline).foregroundStyle(.primary)
                            .keyboardType(.decimalPad)
                        Text("%")
                            .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05)))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // Payment terms
                VStack(alignment: .leading, spacing: 10) {
                    Text("PAYMENT TERMS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    VStack(spacing: 8) {
                        ForEach(termOptions, id: \.key) { option in
                            let isSelected = paymentTerms == option.key
                            Button {
                                withAnimation(.spring(response: 0.3)) { paymentTerms = option.key }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.label)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(isSelected ? .primary : .secondary)
                                        Text(option.desc)
                                            .font(.caption)
                                            .foregroundStyle(isSelected ? .secondary : .tertiary)
                                    }
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                            .font(.body)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(isSelected ? Color.blue.opacity(0.1) : Color.primary.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? Color.blue.opacity(0.3) : Color.primary.opacity(0.05))
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption).foregroundStyle(.red)
                        .padding(.horizontal, 24).padding(.bottom, 8)
                }

                VStack(spacing: 8) {
                    WizardGradientCTA(title: "Create My Profile", loading: isSaving) {
                        await onSave()
                    }
                    Button {
                        Task { await onSave() }
                    } label: {
                        Text("Skip for now")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appeared = true }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { iconFloat = true }
        }
    }
}

// MARK: - Input Field

private struct WizardInput: View {
    let icon: String
    let iconColor: Color
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var optional: Bool = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if optional {
                    Text("optional")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor.opacity(0.8))
                    .frame(width: 20)
                TextField(placeholder, text: $text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .keyboardType(keyboard)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(text.isEmpty ? Color.primary.opacity(0.06) : iconColor.opacity(0.3)))
        }
    }
}

// MARK: - Gradient CTA

private struct WizardGradientCTA: View {
    let title: String
    var disabled: Bool = false
    var loading: Bool = false
    let action: () async -> Void
    @State private var shimmer = false

    var body: some View {
        Button { Task { await action() } } label: {
            Group {
                if loading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.body.weight(.bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                ZStack {
                    LinearGradient(
                        colors: disabled ? [Color.primary.opacity(0.08), Color.primary.opacity(0.08)] : [.wBrandOrange, .wBrandRed],
                        startPoint: .leading, endPoint: .trailing
                    )
                    if !disabled {
                        LinearGradient(colors: [.clear, .white.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing)
                            .offset(x: shimmer ? 300 : -300)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: disabled ? .clear : .wBrandOrange.opacity(0.25), radius: 12, y: 5)
        }
        .disabled(disabled || loading)
        .padding(.horizontal, 24)
        .onAppear {
            guard !disabled else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false).delay(0.5)) { shimmer = true }
        }
    }
}

// MARK: - Keyboard Helper

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
