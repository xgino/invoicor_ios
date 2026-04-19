// Screens/Library/BusinessProfileScreen.swift
// Single business profile editor. Navigated to from LibraryScreen.
// All profile management (add, delete, set default) lives in LibraryScreen.
// Logo is sent as base64 data URI in the JSON body.

import SwiftUI
import UniformTypeIdentifiers

struct BusinessProfileScreen: View {
    @Environment(\.dismiss) private var dismiss
    var auth = AuthManager.shared

    // MARK: - Profile Data
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

    // MARK: - Invoice Defaults
    @State private var defaultTemplate = ""
    @State private var defaultCurrency = ""
    @State private var defaultLanguage = ""
    @State private var defaultTaxRate = ""
    @State private var defaultPaymentTerms = ""
    @State private var defaultDateFormat = "DD/MM/YYYY"
    @State private var defaultDueDays = "30"

    // MARK: - Logo
    @State private var logoBase64: String = ""
    @State private var showFilePicker = false
    @State private var logoImage: UIImage? = nil
    @State private var newLogoBase64: String? = nil

    // MARK: - Dropdown Data
    @State private var currencies: [Currency] = []
    @State private var languages: [Language] = []
    @State private var templates: [InvoiceTemplate] = []
    @State private var showTemplatePicker = false
    private let dateFormats = ["DD/MM/YYYY", "MM/DD/YYYY", "YYYY-MM-DD"]

    // MARK: - UI State
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    // MARK: - Body
    var body: some View {
        if isLoading {
            ProgressView("Loading profile…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
                .task { await loadEverything() }
        } else {
            SubPageLayout(
                title: "Business Profile",
                subtitle: companyName.isEmpty ? nil : companyName,
                onBack: { dismiss() }
            ) {
                logoSection
                companySection
                contactSection
                addressSection
                taxSection
                bankingInternationalSection
                bankingUSSection
                invoiceDefaultsSection
            } bottomBar: {
                if !successMessage.isEmpty { InlineBanner(message: successMessage, style: .success) }
                if !errorMessage.isEmpty { InlineBanner(message: errorMessage, style: .error) }
                ButtonPrimary(title: "Save Changes", isLoading: isSaving) { saveProfile() }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.png, .jpeg, .webP, .svg, .image],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    loadFileFromURL(url)
                }
            }
            .sheet(isPresented: $showTemplatePicker) {
                TemplatePickerSheet(templates: templates, selected: $defaultTemplate)
            }
        }
    }

    // MARK: - Logo Section
    private var logoSection: some View {
        FormSection(title: "Logo") {
            HStack(spacing: 16) {
                Group {
                    if let img = logoImage {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else if !logoBase64.isEmpty, let img = imageFromBase64(logoBase64) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Image(systemName: "building.2").font(.title2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 64, height: 64)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        showFilePicker = true
                    } label: {
                        Label(
                            logoImage != nil || !logoBase64.isEmpty ? "Change Logo" : "Upload Logo",
                            systemImage: "folder"
                        )
                        .font(.subheadline.weight(.medium))
                    }
                    Text("PNG, JPG, SVG or WebP. Transparency preserved.")
                        .font(.caption).foregroundStyle(.tertiary)

                    if logoImage != nil || !logoBase64.isEmpty {
                        Button {
                            logoImage = nil
                            newLogoBase64 = ""
                            logoBase64 = ""
                        } label: {
                            Text("Remove Logo").font(.caption).foregroundStyle(.red)
                        }
                    }
                }
                Spacer()
            }
        }
    }

    private func imageFromBase64(_ dataURI: String) -> UIImage? {
        guard let commaIndex = dataURI.firstIndex(of: ",") else { return nil }
        let base64String = String(dataURI[dataURI.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Form Sections
    private var companySection: some View {
        FormSection(title: "Company", footer: "Company name appears at the top of your invoices.") {
            StyledFormField("Company Name", text: $companyName, placeholder: "Your company or full name")
            StyledFormField("Website", text: $website, placeholder: "https://yoursite.com", keyboard: .URL, autocap: .never)
        }
    }
    private var contactSection: some View {
        FormSection(title: "Contact", footer: "Shown on invoices so clients can reach you.") {
            StyledFormField("Email", text: $email, placeholder: "invoices@company.com", keyboard: .emailAddress, autocap: .never)
            StyledFormField("Phone", text: $phone, placeholder: "+31 6 1234 5678", keyboard: .phonePad)
        }
    }
    private var addressSection: some View {
        FormSection(title: "Address", footer: "Fill in what applies to your country.") {
            StyledFormField("Address Line 1", text: $addressLine1, placeholder: "Street and number")
            StyledFormField("Address Line 2", text: $addressLine2, placeholder: "Suite, building, floor")
            HStack(spacing: 12) {
                StyledFormField("City", text: $city, placeholder: "City")
                StyledFormField("State / Province", text: $stateField, placeholder: "State")
            }
            HStack(spacing: 12) {
                StyledFormField("Postal Code", text: $postalCode, placeholder: "Postal code")
                StyledFormField("Country", text: $country, placeholder: "Country")
            }
        }
    }
    private var taxSection: some View {
        FormSection(title: "Tax & Legal", footer: "Recommended. Shows clients your business is registered.") {
            StyledFormField("Tax ID", text: $taxId, placeholder: "e.g. NL123456789B01")
            StyledFormField("Registration Number", text: $registrationNumber, placeholder: "e.g. KVK 12345678")
        }
    }
    private var bankingInternationalSection: some View {
        FormSection(title: "Banking — International", footer: "For clients who pay via bank transfer.") {
            StyledFormField("Bank Name", text: $bankName, placeholder: "e.g. ING Bank")
            StyledFormField("IBAN", text: $iban, placeholder: "e.g. NL91ABNA0417164300", autocap: .never)
            StyledFormField("SWIFT / BIC", text: $swiftCode, placeholder: "e.g. INGBNL2A", autocap: .characters)
        }
    }
    private var bankingUSSection: some View {
        FormSection(title: "Banking — US Domestic", footer: "Only needed for US domestic transfers.") {
            StyledFormField("Routing Number", text: $routingNumber, placeholder: "e.g. 021000021", keyboard: .numberPad)
            StyledFormField("Account Number", text: $accountNumber, placeholder: "e.g. 1234567890", keyboard: .numberPad)
        }
    }
    private var invoiceDefaultsSection: some View {
        FormSection(title: "Invoice Defaults", footer: "Pre-filled each time you create a new invoice.") {
            FormPicker(label: "Default Currency",
                displayText: currencies.first(where: { $0.code == defaultCurrency }).map { "\($0.symbol)  \($0.code) — \($0.name)" } ?? "Select currency",
                items: currencies, itemLabel: { "\($0.symbol)  \($0.code) — \($0.name)" },
                isSelected: { $0.code == defaultCurrency }, onSelect: { defaultCurrency = $0.code })
            FormPicker(label: "Invoice Language",
                displayText: languages.first(where: { $0.code == defaultLanguage })?.name ?? "Select language",
                items: languages, itemLabel: { $0.name },
                isSelected: { $0.code == defaultLanguage }, onSelect: { defaultLanguage = $0.code })
            VStack(alignment: .leading, spacing: 6) {
                Text("Default Tax Rate").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("0.00", text: $defaultTaxRate).keyboardType(.decimalPad)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 0.5))
                    Text("%").foregroundStyle(.secondary).fontWeight(.medium)
                }
            }
            StyledFormField("Payment Terms", text: $defaultPaymentTerms, placeholder: "e.g. Net 30, Due on Receipt")
            FormPicker(label: "Date Format", displayText: defaultDateFormat,
                items: dateFormats.map { DateFormatItem(format: $0) }, itemLabel: { $0.format },
                isSelected: { $0.format == defaultDateFormat }, onSelect: { defaultDateFormat = $0.format })
            StyledFormField("Default Due Days", text: $defaultDueDays, placeholder: "30", keyboard: .numberPad)
            FormTappableRow(label: "Invoice Template",
                displayText: templates.first(where: { $0.slug == defaultTemplate })?.name ?? defaultTemplate
            ) { showTemplatePicker = true }
        }
    }

    // MARK: - File Picker -> Base64
    private func loadFileFromURL(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let rawData = try? Data(contentsOf: url) else { return }
        let ext = url.pathExtension.lowercased()

        if ext == "svg" {
            let b64 = rawData.base64EncodedString()
            logoImage = UIImage(systemName: "doc.richtext")
            newLogoBase64 = "data:image/svg+xml;base64,\(b64)"
            return
        }

        guard let originalImage = UIImage(data: rawData) else { return }
        let resized = resizeImage(originalImage, maxDimension: 400)
        let isPNG = ext == "png" || detectPNG(rawData)
        let isWebP = ext == "webp"

        let encodedData: Data
        let mime: String
        if isPNG || isWebP {
            guard let pngData = resized.pngData() else { return }
            encodedData = pngData; mime = "image/png"
        } else {
            guard let jpegData = resized.jpegData(compressionQuality: 0.8) else { return }
            encodedData = jpegData; mime = "image/jpeg"
        }

        logoImage = resized
        newLogoBase64 = "data:\(mime);base64,\(encodedData.base64EncodedString())"
    }

    private func detectPNG(_ data: Data) -> Bool {
        guard data.count >= 8 else { return false }
        return data.prefix(8).elementsEqual([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] as [UInt8])
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    // MARK: - Populate from loaded profile
    private func populateFields(from p: BusinessProfile) {
        profileId = p.publicId; companyName = p.companyName; website = p.website
        email = p.email; phone = p.phone
        addressLine1 = p.addressLine1; addressLine2 = p.addressLine2
        city = p.city; stateField = p.state; postalCode = p.postalCode; country = p.country
        taxId = p.taxId; registrationNumber = p.registrationNumber
        bankName = p.bankName; iban = p.iban; swiftCode = p.swiftCode
        routingNumber = p.routingNumber; accountNumber = p.accountNumber
        defaultTemplate = p.defaultTemplate; defaultCurrency = p.defaultCurrency
        defaultLanguage = p.defaultLanguage; defaultTaxRate = p.defaultTaxRate
        defaultPaymentTerms = p.defaultPaymentTerms; defaultDateFormat = p.defaultDateFormat
        defaultDueDays = String(p.defaultDueDays)
        logoBase64 = p.logo ?? ""
        logoImage = nil; newLogoBase64 = nil
    }

    // MARK: - Load Everything
    private func loadEverything() async {
        do {
            let profiles = try await APIClient.shared.request(
                [BusinessProfile].self, method: "GET", path: "/accounts/business-profiles/")
            async let cReq: [Currency] = { (try? await APIClient.shared.request(
                [Currency].self, method: "GET", path: "/invoices/currencies/")) ?? [] }()
            async let lReq: [Language] = { (try? await APIClient.shared.request(
                [Language].self, method: "GET", path: "/invoices/languages/")) ?? [] }()
            async let tReq: [InvoiceTemplate] = { (try? await APIClient.shared.request(
                [InvoiceTemplate].self, method: "GET", path: "/invoices/templates/")) ?? [] }()
            let (c, l, t) = await (cReq, lReq, tReq)
            await MainActor.run {
                currencies = c; languages = l; templates = t
                if let p = profiles.first { populateFields(from: p) }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Failed to load profile"
                isLoading = false
            }
        }
    }

    // MARK: - Save
    private func saveProfile() {
        isSaving = true; errorMessage = ""; successMessage = ""

        var body: [String: Any] = [
            "company_name": companyName.trimmingCharacters(in: .whitespaces),
            "website": website, "email": email, "phone": phone,
            "address_line_1": addressLine1, "address_line_2": addressLine2,
            "city": city, "state": stateField, "postal_code": postalCode, "country": country,
            "tax_id": taxId, "registration_number": registrationNumber,
            "bank_name": bankName, "iban": iban, "swift_code": swiftCode,
            "routing_number": routingNumber, "account_number": accountNumber,
            "default_template": defaultTemplate, "default_currency": defaultCurrency,
            "default_language": defaultLanguage,
            "default_tax_rate": defaultTaxRate.isEmpty ? "0" : defaultTaxRate,
            "default_payment_terms": defaultPaymentTerms,
            "default_date_format": defaultDateFormat,
            "default_due_days": Int(defaultDueDays) ?? 30,
        ]

        if let newLogo = newLogoBase64 { body["logo"] = newLogo }

        Task {
            do {
                let result: BusinessProfile
                if profileId.isEmpty {
                    result = try await APIClient.shared.request(
                        BusinessProfile.self, method: "POST",
                        path: "/accounts/business-profiles/", body: body)
                    await MainActor.run { profileId = result.publicId }
                } else {
                    result = try await APIClient.shared.request(
                        BusinessProfile.self, method: "PUT",
                        path: "/accounts/business-profiles/\(profileId)/", body: body)
                }
                await MainActor.run {
                    logoBase64 = result.logo ?? ""
                    logoImage = nil; newLogoBase64 = nil
                    isSaving = false
                    withAnimation { successMessage = "Profile saved" }
                }
                await AuthManager.shared.refreshMe()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run { withAnimation { successMessage = "" } }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Failed to save"
                    isSaving = false
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run { withAnimation { errorMessage = "" } }
            }
        }
    }
}

// MARK: - Helpers
private struct DateFormatItem: Identifiable { let format: String; var id: String { format } }

// MARK: - Template Picker Sheet
struct TemplatePickerSheet: View {
    let templates: [InvoiceTemplate]
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss
    var auth = AuthManager.shared

    private let tierOrder = ["free", "starter", "pro", "business"]

    private func isTemplateLocked(_ template: InvoiceTemplate) -> Bool {
        let userTier = auth.currentUser?.tier ?? "free"
        let templateTier = template.tier ?? "free"
        let userLevel = tierOrder.firstIndex(of: userTier) ?? 0
        let templateLevel = tierOrder.firstIndex(of: templateTier) ?? 0
        return userLevel < templateLevel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if templates.isEmpty { ProgressView().padding(.top, 60) }
                else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                        ForEach(templates) { template in
                            TemplateCard(
                                template: template,
                                isSelected: selected == template.slug,
                                isLocked: isTemplateLocked(template)
                            ) {
                                if !isTemplateLocked(template) { selected = template.slug }
                            }
                        }
                    }.padding(24)
                }
            }
            .navigationTitle("Invoice Template").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
