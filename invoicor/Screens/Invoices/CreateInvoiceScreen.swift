// Screens/Invoices/CreateInvoiceScreen.swift
// Full-screen modal for creating, editing, and duplicating invoices.
//
// Three modes:
//   1. Create:    CreateInvoiceScreen(isPresented: $show)
//   2. Edit:      CreateInvoiceScreen(isPresented: $show, editInvoice: invoice)
//   3. Duplicate: CreateInvoiceScreen(isPresented: $show, duplicateFrom: invoice)

import SwiftUI
import RevenueCatUI

struct LocalItem: Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var quantity: Double
    var unitPrice: Double
    var amount: Double { quantity * unitPrice }
}

let maxInvoiceItems = 7

struct CreateInvoiceScreen: View {
    @Binding var isPresented: Bool

    var editInvoice: Invoice? = nil
    var duplicateFrom: Invoice? = nil

    private var mode: FormMode {
        if editInvoice != nil { return .edit }
        if duplicateFrom != nil { return .duplicate }
        return .create
    }

    private var sourceInvoice: Invoice? { editInvoice ?? duplicateFrom }

    private enum FormMode {
        case create, edit, duplicate
        var title: String {
            switch self {
            case .create:    return "New Invoice"
            case .edit:      return "Edit Invoice"
            case .duplicate: return "Duplicate Invoice"
            }
        }
        var saveButtonTitle: String {
            switch self {
            case .create:    return "Preview Invoice"
            case .edit:      return "Save Changes"
            case .duplicate: return "Preview Invoice"
            }
        }
    }

    // MARK: - Form State

    @State private var selectedClient: Client? = nil
    @State private var issueDate = Date()
    @State private var dueDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
    @State private var paymentTerms = ""
    @State private var currency = "USD"
    @State private var language = "en"
    @State private var templateSlug = "classic"
    @State private var items: [LocalItem] = []
    @State private var taxRate = ""
    @State private var taxInclusive = false
    @State private var discountType = "none"
    @State private var discountValue = ""
    @State private var notes = ""

    // Business profile
    @State private var businessProfiles: [BusinessProfile] = []
    @State private var selectedProfileId: String = ""

    @State private var currencies: [Currency] = []
    @State private var languages: [Language] = []
    @State private var clients: [Client] = []

    @State private var showClientPicker = false
    @State private var showAddItem = false
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var savedInvoiceId: String? = nil
    @State private var showPreview = false
    @State private var showPaywall = false
    @State private var needsBusinessProfile = false
    @State private var showBusinessProfile = false

    // MARK: - Computed

    private var subtotal: Double { items.reduce(0) { $0 + $1.amount } }
    private var discountAmount: Double {
        let val = Double(discountValue) ?? 0
        switch discountType {
        case "percent": return subtotal * (val / 100)
        case "fixed":   return min(val, subtotal)
        default:        return 0
        }
    }
    private var taxableAmount: Double { subtotal - discountAmount }
    private var taxAmount: Double {
        let rate = Double(taxRate) ?? 0
        if taxInclusive { return taxableAmount - (taxableAmount / (1 + rate / 100)) }
        return taxableAmount * (rate / 100)
    }
    private var total: Double {
        if taxInclusive { return taxableAmount }
        return taxableAmount + taxAmount
    }
    private var currencySymbol: String {
        currencies.first(where: { $0.code == currency })?.symbol ?? currency
    }
    private var isFormValid: Bool { selectedClient != nil && !items.isEmpty }
    private var selectedProfile: BusinessProfile? {
        businessProfiles.first(where: { $0.publicId == selectedProfileId })
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if needsBusinessProfile {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "building.2")
                            .font(.system(size: 48)).foregroundStyle(.secondary)
                        Text("Set up your business first")
                            .font(.title3.weight(.bold))
                        Text("Add your company name, address, and payment details so they appear on your invoices.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                        Button {
                            showBusinessProfile = true
                        } label: {
                            Text("Set Up Business Profile")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal, 40)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if mode == .edit, let inv = editInvoice {
                                modeIndicator(icon: "pencil.circle", text: "Editing \(inv.invoiceNumber)", color: .blue)
                            } else if mode == .duplicate, let inv = duplicateFrom {
                                modeIndicator(icon: "doc.on.doc", text: "Duplicating from \(inv.invoiceNumber)", color: .purple)
                            }

                            // Business profile picker (only when multiple profiles exist)
                            if businessProfiles.count > 1 {
                                businessProfileSection
                            }

                            clientSection
                            detailsSection
                            itemsSection
                            taxDiscountSection
                            totalsSection
                            notesSection
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }

                    VStack {
                        Spacer()
                        VStack(spacing: 8) {
                            if !errorMessage.isEmpty {
                                InlineBanner(message: errorMessage, style: .error)
                                    .padding(.horizontal, horizontalPadding)
                            }
                            ButtonPrimary(
                                title: mode.saveButtonTitle,
                                isLoading: isSaving,
                                isDisabled: !isFormValid
                            ) { primaryAction() }
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, 8)
                        }
                        .background(Rectangle().fill(.ultraThinMaterial).ignoresSafeArea(.all, edges: .bottom))
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                if mode == .create || mode == .duplicate {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isFormValid ? "Save" : "Save Draft") { saveDraft() }
                            .disabled(isSaving)
                    }
                }
            }
            .task { await loadFormData() }
            .sheet(isPresented: $showClientPicker) {
                ClientPickerSheet(clients: $clients, selected: $selectedClient)
            }
            .sheet(isPresented: $showAddItem) {
                AddItemSheet(currencySymbol: currencySymbol) { newItem in items.append(newItem) }
            }
            .navigationDestination(isPresented: $showPreview) {
                if let invoiceId = savedInvoiceId {
                    InvoiceDetailScreen(invoiceId: invoiceId)
                }
            }
            .fullScreenCover(isPresented: $showPaywall) { PaywallScreen() }
            .fullScreenCover(isPresented: $showBusinessProfile, onDismiss: {
                Task { await loadFormData() }
            }) {
                NavigationStack { BusinessProfileScreen() }
            }
        }
    }

    // MARK: - Mode Indicator

    private func modeIndicator(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Business Profile Picker

    private var businessProfileSection: some View {
        FormSection(title: "Business Profile") {
            FormPicker(
                label: "Send From",
                displayText: selectedProfile?.displayName ?? "Select profile",
                items: businessProfiles,
                itemLabel: { profile in
                    let suffix = profile.isDefault ? " (Default)" : ""
                    return (profile.displayName) + suffix
                },
                isSelected: { $0.publicId == selectedProfileId },
                onSelect: { profile in
                    selectedProfileId = profile.publicId
                    applyProfileDefaults(profile)
                }
            )
        }
    }

    /// When user switches business profile, update the form defaults
    private func applyProfileDefaults(_ profile: BusinessProfile) {
        // Only update defaults if in create/duplicate mode and fields haven't been manually changed
        if mode != .edit {
            templateSlug = profile.defaultTemplate
            currency = profile.defaultCurrency
            language = profile.defaultLanguage
            if taxRate.isEmpty || taxRate == "0" {
                taxRate = profile.defaultTaxRate
            }
            if paymentTerms.isEmpty {
                paymentTerms = profile.defaultPaymentTerms
            }
            dueDate = Calendar.current.date(
                byAdding: .day, value: profile.defaultDueDays, to: issueDate
            ) ?? dueDate
        }
    }

    // MARK: - Client Section

    private var clientSection: some View {
        FormSection(title: "Bill To") {
            Button { showClientPicker = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill").font(.title3).foregroundStyle(.secondary)
                    if let client = selectedClient {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.displayName).foregroundStyle(.primary)
                            if !client.email.isEmpty { Text(client.email).font(.caption).foregroundStyle(.secondary) }
                        }
                    } else {
                        Text("Select Client").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 0.5))
                .contentShape(Rectangle())
            }
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        FormSection(title: "Details") {
            DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
            DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
            FormPicker(
                label: "Currency",
                displayText: currencies.first(where: { $0.code == currency }).map { "\($0.symbol)  \($0.code) — \($0.name)" } ?? "Select",
                items: currencies, itemLabel: { "\($0.symbol)  \($0.code) — \($0.name)" },
                isSelected: { $0.code == currency }, onSelect: { currency = $0.code }
            )
            FormPicker(
                label: "Language",
                displayText: languages.first(where: { $0.code == language })?.name ?? "Select",
                items: languages, itemLabel: { $0.name },
                isSelected: { $0.code == language }, onSelect: { language = $0.code }
            )
            StyledFormField("Payment Terms", text: $paymentTerms, placeholder: "e.g. Net 30, Due on Receipt")
        }
    }

    // MARK: - Items

    private var itemsSection: some View {
        FormSection(title: "Items") {
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cart").font(.title2).foregroundStyle(.secondary)
                    Text("No items yet").font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 16)
            } else {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.body).lineLimit(1)
                            if !item.description.isEmpty {
                                Text(item.description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Text("\(formatQty(item.quantity)) x \(currencySymbol)\(formatPrice(item.unitPrice))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(currencySymbol)\(formatPrice(item.amount))").font(.body.weight(.medium))
                        Button { items.removeAll { $0.id == item.id } } label: {
                            Image(systemName: "trash").font(.caption).foregroundStyle(.red)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 0.5))
                }
            }
            if items.count < maxInvoiceItems {
                Button { showAddItem = true } label: {
                    HStack(spacing: 6) { Image(systemName: "plus.circle.fill"); Text("Add Item").fontWeight(.medium) }
                        .font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 10)
                }
            } else {
                Text("Maximum \(maxInvoiceItems) items reached")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Tax & Discount

    private var taxDiscountSection: some View {
        FormSection(title: "Tax & Discount") {
            HStack {
                Text("Tax Rate").font(.subheadline); Spacer()
                TextField("0", text: $taxRate)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 0.5))
                Text("%").foregroundStyle(.secondary)
            }
            Toggle("Tax Inclusive", isOn: $taxInclusive)
            VStack(alignment: .leading, spacing: 6) {
                Text("Discount").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $discountType) {
                    Text("None").tag("none"); Text("Percentage").tag("percent"); Text("Fixed").tag("fixed")
                }.pickerStyle(.segmented)
            }
            if discountType != "none" {
                HStack {
                    TextField("0", text: $discountValue).keyboardType(.decimalPad)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 0.5))
                    Text(discountType == "percent" ? "%" : currencySymbol).foregroundStyle(.secondary).fontWeight(.medium)
                }
            }
        }
    }

    // MARK: - Totals

    private var totalsSection: some View {
        VStack(spacing: 8) {
            totalRow("Subtotal", value: subtotal)
            if discountAmount > 0 { totalRow("Discount", value: -discountAmount, color: .green) }
            if (Double(taxRate) ?? 0) > 0 { totalRow("Tax (\(taxRate)%)", value: taxAmount) }
            Divider()
            HStack {
                Text("Total").font(.title3.weight(.bold)); Spacer()
                Text("\(currencySymbol)\(formatPrice(total))").font(.title3.weight(.bold))
            }
        }
        .padding(16).background(Color(.systemGray6).opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func totalRow(_ label: String, value: Double, color: Color = .primary) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary); Spacer()
            Text("\(currencySymbol)\(formatPrice(value))").font(.subheadline).foregroundStyle(color)
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        FormSection(title: "Notes") {
            FormTextEditor(label: "", text: $notes, placeholder: "Payment instructions, thank you message…", minHeight: 80)
        }
    }

    // MARK: - Helpers

    private func formatPrice(_ value: Double) -> String { String(format: "%.2f", value) }
    private func formatQty(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.2f", value)
    }
    private var dateFormatter: DateFormatter { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }
    private var horizontalPadding: CGFloat {
        let w = UIScreen.main.bounds.width; if w > 430 { return 24 }; if w > 390 { return 20 }; return 16
    }

    // MARK: - Load Form Data

    private func loadFormData() async {
        do {
            async let cReq = APIClient.shared.request([Currency].self, method: "GET", path: "/invoices/currencies/")
            async let lReq = APIClient.shared.request([Language].self, method: "GET", path: "/invoices/languages/")
            async let clReq = APIClient.shared.request([Client].self, method: "GET", path: "/accounts/clients/")
            async let pReq = APIClient.shared.request([BusinessProfile].self, method: "GET", path: "/accounts/business-profiles/")
            let (c, l, cl, p) = try await (cReq, lReq, clReq, pReq)

            await MainActor.run {
                currencies = c; languages = l; clients = cl; businessProfiles = p

                if let source = sourceInvoice {
                    prefillFromInvoice(source)
                    if let clientId = source.clientSnapshot["public_id"]?.stringValue {
                        selectedClient = clients.first { $0.publicId == clientId }
                    } else {
                        let name = source.clientName
                        selectedClient = clients.first { $0.displayName == name }
                    }
                    // For edit/duplicate, try to match the profile used
                    // Default to the default profile
                    if let defaultProfile = p.first(where: { $0.isDefault }) ?? p.first {
                        selectedProfileId = defaultProfile.publicId
                    }
                    needsBusinessProfile = false
                } else if let defaultProfile = p.first(where: { $0.isDefault }) ?? p.first,
                          !defaultProfile.companyName.isEmpty {
                    // Create mode: select default profile and apply its defaults
                    selectedProfileId = defaultProfile.publicId
                    applyProfileDefaults(defaultProfile)
                    needsBusinessProfile = false
                } else {
                    needsBusinessProfile = true
                }

                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Failed to load"
                isLoading = false
            }
        }
    }

    private func prefillFromInvoice(_ inv: Invoice) {
        currency = inv.currency; language = inv.language
        templateSlug = inv.templateSlug; paymentTerms = inv.paymentTerms
        notes = inv.notes; taxRate = inv.taxRate; taxInclusive = inv.taxInclusive
        discountType = inv.discountType; discountValue = inv.discountValue

        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        if mode == .edit {
            issueDate = df.date(from: inv.issueDate) ?? Date()
            dueDate = df.date(from: inv.dueDate) ?? Date()
        } else {
            issueDate = Date()
            if let originalIssue = df.date(from: inv.issueDate),
               let originalDue = df.date(from: inv.dueDate) {
                let daysBetween = Calendar.current.dateComponents([.day], from: originalIssue, to: originalDue).day ?? 30
                dueDate = Calendar.current.date(byAdding: .day, value: daysBetween, to: issueDate) ?? Date()
            }
        }

        items = inv.items.map { item in
            LocalItem(name: item.name, description: item.description,
                      quantity: Double(item.quantity) ?? 1, unitPrice: Double(item.unitPrice) ?? 0)
        }

        if mode == .edit { savedInvoiceId = inv.publicId }
    }

    // MARK: - Build API Body

    private func buildBody() -> [String: Any] {
        var body: [String: Any] = [
            "template_slug": templateSlug, "language": language, "currency": currency,
            "issue_date": dateFormatter.string(from: issueDate),
            "due_date": dateFormatter.string(from: dueDate),
            "payment_terms": paymentTerms, "notes": notes,
            "tax_rate": taxRate.isEmpty ? "0" : taxRate,
            "tax_inclusive": taxInclusive,
            "discount_type": discountType,
            "discount_value": discountValue.isEmpty ? "0" : discountValue,
            "items": items.enumerated().map { i, item in
                ["name": item.name, "description": item.description,
                 "quantity": String(item.quantity), "unit_price": String(item.unitPrice),
                 "sort_order": i] as [String: Any]
            }
        ]
        if let client = selectedClient { body["client_id"] = client.publicId }
        // Send selected business profile so the API uses that sender
        if !selectedProfileId.isEmpty { body["business_profile_id"] = selectedProfileId }
        return body
    }

    // MARK: - Save Logic

    private func primaryAction() {
        switch mode {
        case .edit:      saveEdit()
        case .create:    saveAndPreview()
        case .duplicate: saveAndPreview()
        }
    }

    private func saveEdit() {
        guard let invoiceId = editInvoice?.publicId else { return }
        isSaving = true; errorMessage = ""
        Task {
            do {
                _ = try await APIClient.shared.request(
                    Invoice.self, method: "PUT", path: "/invoices/\(invoiceId)/", body: buildBody())
                await MainActor.run { isSaving = false; isPresented = false }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Failed to save"; isSaving = false
                }
            }
        }
    }

    private func saveAndPreview() {
        if savedInvoiceId != nil { showPreview = true; return }
        isSaving = true; errorMessage = ""
        Task {
            do {
                let result = try await APIClient.shared.request(
                    Invoice.self, method: "POST", path: "/invoices/", body: buildBody())
                await MainActor.run { savedInvoiceId = result.publicId; isSaving = false; showPreview = true }
            } catch let error as APIError {
                if case .limitReached = error {
                    await MainActor.run { isSaving = false; showPaywall = true }
                } else {
                    await MainActor.run { errorMessage = error.errorDescription ?? "Failed to save"; isSaving = false }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isSaving = false }
            }
        }
    }

    private func saveDraft() {
        guard savedInvoiceId == nil else { isPresented = false; return }
        isSaving = true; errorMessage = ""
        Task {
            do {
                _ = try await APIClient.shared.request(
                    Invoice.self, method: "POST", path: "/invoices/", body: buildBody())
                await MainActor.run { isSaving = false; isPresented = false }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Failed to save"; isSaving = false
                }
            }
        }
    }
}
