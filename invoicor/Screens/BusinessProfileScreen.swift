// Screens/BusinessProfileScreen.swift
// Full business profile editor. Pushed from Settings.
// Currency + Language loaded from API as proper pickers.
// Floating save button at bottom. No nav title bar clutter.
import SwiftUI
import PhotosUI

struct BusinessProfileScreen: View {
    @Environment(\.dismiss) private var dismiss

    // Profile data
    @State private var profileId = ""
    @State private var companyName = ""
    @State private var website = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var addressLine1 = ""
    @State private var addressLine2 = ""
    @State private var city = ""
    @State private var stateField = ""
    @State private var postalCode = ""
    @State private var country = ""
    @State private var taxId = ""
    @State private var registrationNumber = ""
    @State private var bankName = ""
    @State private var iban = ""
    @State private var swiftCode = ""
    @State private var routingNumber = ""
    @State private var accountNumber = ""
    @State private var paypalEmail = ""
    @State private var venmoHandle = ""

    // Invoice defaults
    @State private var defaultTemplate = ""
    @State private var defaultCurrency = ""
    @State private var defaultLanguage = ""
    @State private var defaultTaxRate = ""
    @State private var defaultPaymentTerms = ""

    // Logo
    @State private var logoURL: String? = nil
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var logoImage: UIImage? = nil

    // Dropdown data from API
    @State private var currencies: [Currency] = []
    @State private var languages: [Language] = []

    // Templates
    @State private var templates: [InvoiceTemplate] = []
    @State private var showTemplatePicker = false

    // UI state
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            if isLoading {
                ProgressView("Loading profile...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // All form sections
                        VStack(alignment: .leading, spacing: 24) {
                            logoSection
                            companySection
                            contactSection
                            addressSection
                            taxSection
                            bankingInternationalSection
                            bankingUSSection
                            digitalPaymentsSection
                            invoiceDefaultsSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 100) // Space for floating button
                    }
                }

                // Floating save button
                VStack(spacing: 8) {
                    // Error / Success messages
                    if !errorMessage.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.callout)
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 16)
                    }

                    if !successMessage.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(successMessage)
                                .font(.callout)
                                .foregroundStyle(.green)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 16)
                    }

                    ButtonPrimary(
                        title: "Save Changes",
                        isLoading: isSaving
                    ) {
                        saveProfile()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(.all, edges: .bottom)
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadEverything() }
        .onChange(of: selectedPhoto) { _, newValue in
            loadPhoto(from: newValue)
        }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet(
                templates: templates,
                selected: $defaultTemplate
            )
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        formSection(title: "Logo") {
            HStack(spacing: 16) {
                Group {
                    if let img = logoImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "building.2")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 64, height: 64)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images
                    ) {
                        Text(logoImage != nil ? "Change Logo" : "Upload Logo")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Text("Optional. Appears on your invoices.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Company Section

    private var companySection: some View {
        formSection(
            title: "Company",
            footer: "Company name is recommended. Everything else is optional."
        ) {
            formField("Company Name", text: $companyName, placeholder: "Your company or full name")
            formField("Website", text: $website, placeholder: "https://yoursite.com", keyboard: .URL, autocap: .never)
        }
    }

    // MARK: - Contact Section

    private var contactSection: some View {
        formSection(
            title: "Contact",
            footer: "Shown on your invoices so clients can reach you."
        ) {
            formField("Email", text: $email, placeholder: "invoices@company.com", keyboard: .emailAddress, autocap: .never)
            formField("Phone", text: $phone, placeholder: "+31 6 1234 5678", keyboard: .phonePad)
        }
    }

    // MARK: - Address Section

    private var addressSection: some View {
        formSection(
            title: "Address",
            footer: "Optional. Fill in what applies to your region."
        ) {
            formField("Address Line 1", text: $addressLine1, placeholder: "Street and number")
            formField("Address Line 2", text: $addressLine2, placeholder: "Suite, building, floor")
            HStack(spacing: 12) {
                formField("City", text: $city, placeholder: "City")
                formField("State / Province", text: $stateField, placeholder: "State")
            }
            HStack(spacing: 12) {
                formField("Postal Code", text: $postalCode, placeholder: "Postal code")
                formField("Country", text: $country, placeholder: "Country")
            }
        }
    }

    // MARK: - Tax & Legal Section

    private var taxSection: some View {
        formSection(
            title: "Tax & Legal",
            footer: "Recommended. Shows clients your business is registered."
        ) {
            formField("Tax ID", text: $taxId, placeholder: "e.g. NL123456789B01 or 12-3456789")
            formField("Registration Number", text: $registrationNumber, placeholder: "e.g. KVK 12345678")
        }
    }

    // MARK: - Banking International

    private var bankingInternationalSection: some View {
        formSection(
            title: "Banking (International)",
            footer: "Optional. For clients who pay via bank transfer."
        ) {
            formField("Bank Name", text: $bankName, placeholder: "e.g. ING Bank")
            formField("IBAN", text: $iban, placeholder: "e.g. NL91ABNA0417164300")
            formField("SWIFT / BIC", text: $swiftCode, placeholder: "e.g. INGBNL2A")
        }
    }

    // MARK: - Banking US

    private var bankingUSSection: some View {
        formSection(
            title: "Banking (US Domestic)",
            footer: "Optional. Only needed for US domestic transfers."
        ) {
            formField("Routing Number", text: $routingNumber, placeholder: "e.g. 021000021", keyboard: .numberPad)
            formField("Account Number", text: $accountNumber, placeholder: "e.g. 1234567890", keyboard: .numberPad)
        }
    }

    // MARK: - Digital Payments

    private var digitalPaymentsSection: some View {
        formSection(
            title: "Digital Payments",
            footer: "Optional. Payment links can appear on your invoice."
        ) {
            formField("PayPal Email", text: $paypalEmail, placeholder: "paypal@company.com", keyboard: .emailAddress, autocap: .never)
            formField("Venmo Handle", text: $venmoHandle, placeholder: "@yourhandle")
        }
    }

    // MARK: - Invoice Defaults

    private var invoiceDefaultsSection: some View {
        formSection(
            title: "Invoice Defaults",
            footer: "Pre-filled when you create a new invoice. Language translates labels like \"Amount\" → \"Bedrag\" for international clients."
        ) {
            // Currency picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Default Currency")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Menu {
                    ForEach(currencies) { c in
                        Button {
                            defaultCurrency = c.code
                        } label: {
                            HStack {
                                Text("\(c.symbol)  \(c.code) — \(c.name)")
                                if defaultCurrency == c.code {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let selected = currencies.first(where: { $0.code == defaultCurrency }) {
                            Text("\(selected.symbol)  \(selected.code) — \(selected.name)")
                                .foregroundStyle(.primary)
                        } else {
                            Text("Select currency")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Language picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Default Language")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Menu {
                    ForEach(languages) { l in
                        Button {
                            defaultLanguage = l.code
                        } label: {
                            HStack {
                                Text(l.name)
                                if defaultLanguage == l.code {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let selected = languages.first(where: { $0.code == defaultLanguage }) {
                            Text(selected.name)
                                .foregroundStyle(.primary)
                        } else {
                            Text("Select language")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Tax rate
            VStack(alignment: .leading, spacing: 6) {
                Text("Default Tax Rate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("0.00", text: $defaultTaxRate)
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("%")
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                }
            }

            // Payment terms
            formField("Payment Terms", text: $defaultPaymentTerms, placeholder: "e.g. Net 30, Due on Receipt, 14 days")

            // Template picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Invoice Template")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    showTemplatePicker = true
                } label: {
                    HStack {
                        Text(templateDisplayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Reusable Form Helpers

    private func formSection(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(spacing: 12) {
                content()
            }

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.top, 4)
        }
    }

    private func formField(
        _ label: String,
        text: Binding<String>,
        placeholder: String = "",
        keyboard: UIKeyboardType = .default,
        autocap: TextInputAutocapitalization = .sentences
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled()
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Template display name

    private var templateDisplayName: String {
        if defaultTemplate.isEmpty { return "Choose a template" }
        return templates.first(where: { $0.slug == defaultTemplate })?.name ?? defaultTemplate
    }

    // MARK: - Photo Picker

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                await MainActor.run { logoImage = img }
            }
        }
    }

    // MARK: - Load Everything

    private func loadEverything() async {
        do {
            async let profilesReq = APIClient.shared.request(
                [BusinessProfile].self, method: "GET", path: "/accounts/business-profiles/"
            )
            async let currenciesReq = APIClient.shared.request(
                [Currency].self, method: "GET", path: "/invoices/currencies/"
            )
            async let languagesReq = APIClient.shared.request(
                [Language].self, method: "GET", path: "/invoices/languages/"
            )
            async let templatesReq = APIClient.shared.request(
                [InvoiceTemplate].self, method: "GET", path: "/invoices/templates/"
            )

            let (profiles, fetchedCurrencies, fetchedLanguages, fetchedTemplates) =
                try await (profilesReq, currenciesReq, languagesReq, templatesReq)

            await MainActor.run {
                currencies = fetchedCurrencies
                languages = fetchedLanguages
                templates = fetchedTemplates

                if let p = profiles.first {
                    profileId = p.publicId
                    companyName = p.companyName
                    website = p.website
                    email = p.email
                    phone = p.phone
                    addressLine1 = p.addressLine1
                    addressLine2 = p.addressLine2
                    city = p.city
                    stateField = p.state
                    postalCode = p.postalCode
                    country = p.country
                    taxId = p.taxId
                    registrationNumber = p.registrationNumber
                    bankName = p.bankName
                    iban = p.iban
                    swiftCode = p.swiftCode
                    routingNumber = p.routingNumber
                    accountNumber = p.accountNumber
                    paypalEmail = p.paypalEmail
                    venmoHandle = p.venmoHandle
                    defaultTemplate = p.defaultTemplate
                    defaultCurrency = p.defaultCurrency
                    defaultLanguage = p.defaultLanguage
                    defaultTaxRate = p.defaultTaxRate
                    defaultPaymentTerms = p.defaultPaymentTerms
                    logoURL = p.logo
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Failed to load profile"
                isLoading = false
            }
        }
    }

    // MARK: - Save Profile

    private func saveProfile() {
        isSaving = true
        errorMessage = ""
        successMessage = ""

        let body: [String: Any] = [
            "company_name": companyName.trimmingCharacters(in: .whitespaces),
            "website": website,
            "email": email,
            "phone": phone,
            "address_line_1": addressLine1,
            "address_line_2": addressLine2,
            "city": city,
            "state": stateField,
            "postal_code": postalCode,
            "country": country,
            "tax_id": taxId,
            "registration_number": registrationNumber,
            "bank_name": bankName,
            "iban": iban,
            "swift_code": swiftCode,
            "routing_number": routingNumber,
            "account_number": accountNumber,
            "paypal_email": paypalEmail,
            "venmo_handle": venmoHandle,
            "default_template": defaultTemplate,
            "default_currency": defaultCurrency,
            "default_language": defaultLanguage,
            "default_tax_rate": defaultTaxRate,
            "default_payment_terms": defaultPaymentTerms,
        ]

        Task {
            do {
                let _ = try await APIClient.shared.request(
                    BusinessProfile.self,
                    method: "PUT",
                    path: "/accounts/business-profiles/\(profileId)/",
                    body: body
                )
                await MainActor.run {
                    isSaving = false
                    successMessage = "Profile saved successfully"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        successMessage = ""
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Failed to save. Check your connection and try again."
                    isSaving = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        errorMessage = ""
                    }
                }
            }
        }
    }
}

// MARK: - Template Picker Sheet

struct TemplatePickerSheet: View {
    let templates: [InvoiceTemplate]
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if templates.isEmpty {
                    ProgressView()
                        .padding(.top, 60)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 16
                    ) {
                        ForEach(templates) { template in
                            TemplateCard(
                                template: template,
                                isSelected: selected == template.slug
                            ) {
                                selected = template.slug
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Invoice Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
