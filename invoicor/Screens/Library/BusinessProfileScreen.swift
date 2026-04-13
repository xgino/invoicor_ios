// Screens/Library/BusinessProfileScreen.swift
// Full business profile editor with multi-profile support.
// Logo is sent as base64 data URI in the JSON body — no multipart upload.

import SwiftUI
import PhotosUI

struct BusinessProfileScreen: View {
    @Environment(\.dismiss) private var dismiss
    var auth = AuthManager.shared

    // MARK: - Profile List
    @State private var allProfiles: [BusinessProfile] = []
    @State private var selectedProfileIndex: Int = 0

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
    @State private var logoBase64: String = ""   // Stored data URI from API
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var logoImage: UIImage? = nil  // Locally picked image (not yet saved)
    @State private var newLogoBase64: String? = nil  // Converted base64 of new pick

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
    @State private var showDeleteProfileConfirm = false

    private var profileLimit: Int { auth.limits?.businessProfiles ?? 1 }
    private var canAddProfile: Bool { allProfiles.count < profileLimit }

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
                trailingButton: canAddProfile ? AnyView(
                    Button { Task { await createNewProfile() } } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                ) : nil,
                onBack: { dismiss() }
            ) {
                if allProfiles.count > 1 { profileSwitcher }
                logoSection
                companySection
                contactSection
                addressSection
                taxSection
                bankingInternationalSection
                bankingUSSection
                invoiceDefaultsSection
                if allProfiles.count > 1 { deleteProfileSection }
            } bottomBar: {
                if !successMessage.isEmpty { InlineBanner(message: successMessage, style: .success) }
                if !errorMessage.isEmpty { InlineBanner(message: errorMessage, style: .error) }
                ButtonPrimary(title: "Save Changes", isLoading: isSaving) { saveProfile() }
            }
            .onChange(of: selectedPhoto) { _, newValue in loadPhoto(from: newValue) }
            .sheet(isPresented: $showTemplatePicker) {
                TemplatePickerSheet(templates: templates, selected: $defaultTemplate)
            }
            .alert("Delete this profile?", isPresented: $showDeleteProfileConfirm) {
                Button("Delete", role: .destructive) { Task { await deleteCurrentProfile() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete \"\(companyName.isEmpty ? "this profile" : companyName)\". Existing invoices are not affected.")
            }
        }
    }

    // MARK: - Profile Switcher
    private var profileSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(allProfiles.enumerated()), id: \.element.publicId) { index, profile in
                    Button { switchToProfile(at: index) } label: {
                        HStack(spacing: 8) {
                            if profile.isDefault {
                                Image(systemName: "star.fill").font(.caption2).foregroundStyle(.orange)
                            }
                            Text(profile.companyName.isEmpty ? "Profile \(index + 1)" : profile.companyName)
                                .font(.subheadline.weight(index == selectedProfileIndex ? .semibold : .regular))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(index == selectedProfileIndex ? Color.blue.opacity(0.1) : Color(.systemGray6).opacity(0.7))
                        .foregroundStyle(index == selectedProfileIndex ? .blue : .primary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(index == selectedProfileIndex ? Color.blue.opacity(0.3) : .clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var deleteProfileSection: some View {
        Button(role: .destructive) { showDeleteProfileConfirm = true } label: {
            HStack(spacing: 8) { Image(systemName: "trash"); Text("Delete This Profile") }
                .font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 12)
        }.padding(.top, 8)
    }

    // MARK: - Logo Section
    private var logoSection: some View {
        FormSection(title: "Logo") {
            HStack(spacing: 16) {
                // Show picked image, or existing base64 logo, or placeholder
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
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Text(logoImage != nil || !logoBase64.isEmpty ? "Change Logo" : "Upload Logo")
                            .font(.subheadline.weight(.medium))
                    }
                    Text("Appears on your invoices. Optional.").font(.caption).foregroundStyle(.tertiary)

                    // Remove logo button
                    if logoImage != nil || !logoBase64.isEmpty {
                        Button {
                            logoImage = nil
                            newLogoBase64 = ""  // Empty string = remove logo
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

    /// Decode a base64 data URI to UIImage for display
    private func imageFromBase64(_ dataURI: String) -> UIImage? {
        guard let commaIndex = dataURI.firstIndex(of: ",") else { return nil }
        let base64String = String(dataURI[dataURI.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Form Sections (unchanged)
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

    // MARK: - Photo Picker → Base64
    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                // Resize to max 400px (keeps aspect ratio) then compress
                let resized = resizeImage(img, maxDimension: 400)
                let compressed = resized.jpegData(compressionQuality: 0.7) ?? data
                let b64 = compressed.base64EncodedString()
                let dataURI = "data:image/jpeg;base64,\(b64)"

                await MainActor.run {
                    logoImage = resized
                    newLogoBase64 = dataURI
                }
            }
        }
    }

    /// Resize image so the longest side is at most maxDimension pixels.
    /// Keeps aspect ratio. Returns original if already small enough.
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    // MARK: - Profile Helpers
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
        logoImage = nil; selectedPhoto = nil; newLogoBase64 = nil
    }

    private func switchToProfile(at index: Int) {
        guard index < allProfiles.count else { return }
        selectedProfileIndex = index
        populateFields(from: allProfiles[index])
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
                allProfiles = profiles; currencies = c; languages = l; templates = t
                if let p = profiles.first { populateFields(from: p); selectedProfileIndex = 0 }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Failed to load profile"
                isLoading = false
            }
        }
    }

    // MARK: - Create / Delete Profile
    private func createNewProfile() async {
        do {
            let created = try await APIClient.shared.request(BusinessProfile.self,
                method: "POST", path: "/accounts/business-profiles/", body: ["company_name": "New Profile"])
            await MainActor.run {
                allProfiles.append(created)
                selectedProfileIndex = allProfiles.count - 1
                populateFields(from: created); companyName = ""
            }
        } catch {
            await MainActor.run { errorMessage = (error as? APIError)?.errorDescription ?? "Failed to create profile" }
        }
    }

    private func deleteCurrentProfile() async {
        guard !profileId.isEmpty, allProfiles.count > 1 else { return }
        do {
            try await APIClient.shared.requestNoContent(method: "DELETE", path: "/accounts/business-profiles/\(profileId)/")
            await MainActor.run {
                allProfiles.remove(at: selectedProfileIndex)
                let idx = max(0, selectedProfileIndex - 1); selectedProfileIndex = idx
                if let p = allProfiles[safe: idx] { populateFields(from: p) }
            }
        } catch {
            await MainActor.run { errorMessage = (error as? APIError)?.errorDescription ?? "Failed to delete" }
        }
    }

    // MARK: - Save Profile (pure JSON — no multipart)
    private func saveProfile() {
        isSaving = true; errorMessage = ""; successMessage = ""

        var body: [String: Any] = [
            "company_name": companyName.trimmingCharacters(in: .whitespaces),
            "website": website,
            "email": email, "phone": phone,
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

        // Include logo if changed (new pick or removed)
        if let newLogo = newLogoBase64 {
            body["logo"] = newLogo  // Empty string = remove logo
        }

        Task {
            do {
                let result: BusinessProfile
                if profileId.isEmpty {
                    result = try await APIClient.shared.request(
                        BusinessProfile.self, method: "POST",
                        path: "/accounts/business-profiles/", body: body
                    )
                    await MainActor.run { profileId = result.publicId }
                } else {
                    result = try await APIClient.shared.request(
                        BusinessProfile.self, method: "PUT",
                        path: "/accounts/business-profiles/\(profileId)/", body: body
                    )
                }

                await MainActor.run {
                    if let idx = allProfiles.firstIndex(where: { $0.publicId == result.publicId }) {
                        allProfiles[idx] = result
                    } else {
                        allProfiles.append(result)
                    }
                    // Update local state from saved result
                    logoBase64 = result.logo ?? ""
                    logoImage = nil
                    newLogoBase64 = nil
                    isSaving = false
                    withAnimation { successMessage = "Profile saved" }
                }
                await AuthManager.shared.refreshMe()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run { withAnimation { successMessage = "" } }
            } catch {
                await MainActor.run { errorMessage = (error as? APIError)?.errorDescription ?? "Failed to save"; isSaving = false }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run { withAnimation { errorMessage = "" } }
            }
        }
    }
}

// MARK: - Helpers
private struct DateFormatItem: Identifiable { let format: String; var id: String { format } }
private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

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
