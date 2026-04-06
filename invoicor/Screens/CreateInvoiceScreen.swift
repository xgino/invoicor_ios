// Screens/CreateInvoiceScreen.swift
// Full-screen modal for creating invoices.
// Template comes from business profile defaults — not selectable here.
// Tracks saved state to prevent double-creation.
import SwiftUI

// Local item model (lives in form state until saved to API)
struct LocalItem: Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var quantity: Double
    var unitPrice: Double
    var amount: Double { quantity * unitPrice }
}

// Max items per invoice — matches API limit.
// Change this one number to increase the limit everywhere.
let maxInvoiceItems = 7

struct CreateInvoiceScreen: View {
    @Binding var isPresented: Bool

    // Form state
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

    // API data
    @State private var currencies: [Currency] = []
    @State private var languages: [Language] = []
    @State private var clients: [Client] = []

    // Sheets
    @State private var showClientPicker = false
    @State private var showAddItem = false

    // UI state
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage = ""

    // Saved invoice tracking (prevents double-creation)
    @State private var savedInvoiceId: String? = nil
    @State private var showPreview = false
    @State private var showPaywall = false

    // MARK: - Computed Totals

    private var subtotal: Double {
        items.reduce(0) { $0 + $1.amount }
    }

    private var discountAmount: Double {
        let val = Double(discountValue) ?? 0
        switch discountType {
        case "percent": return subtotal * (val / 100)
        case "fixed": return min(val, subtotal)
        default: return 0
        }
    }

    private var taxableAmount: Double {
        subtotal - discountAmount
    }

    private var taxAmount: Double {
        let rate = Double(taxRate) ?? 0
        if taxInclusive {
            return taxableAmount - (taxableAmount / (1 + rate / 100))
        }
        return taxableAmount * (rate / 100)
    }

    private var total: Double {
        if taxInclusive { return taxableAmount }
        return taxableAmount + taxAmount
    }

    private var currencySymbol: String {
        currencies.first(where: { $0.code == currency })?.symbol ?? currency
    }

    private var isFormValid: Bool {
        selectedClient != nil && !items.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            clientSection
                            detailsSection
                            itemsSection
                            taxDiscountSection
                            totalsSection
                            notesSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }

                    // Sticky bottom bar
                    VStack {
                        Spacer()
                        VStack(spacing: 8) {
                            if !errorMessage.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text(errorMessage).font(.callout)
                                    Spacer()
                                    Button { errorMessage = "" } label: {
                                        Image(systemName: "xmark").font(.caption)
                                    }
                                }
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Color.red)
                            }

                            ButtonPrimary(
                                title: "Preview Invoice",
                                isLoading: isSaving,
                                isDisabled: !isFormValid
                            ) {
                                saveAndPreview()
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
            }
            .navigationTitle("New Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Draft") { saveDraft() }
                        .disabled(isSaving || !isFormValid)
                }
            }
            .task { await loadFormData() }
            .sheet(isPresented: $showClientPicker) {
                ClientPickerSheet(
                    clients: $clients,
                    selected: $selectedClient
                )
            }
            .sheet(isPresented: $showAddItem) {
                AddItemSheet { newItem in
                    items.append(newItem)
                }
            }
            .navigationDestination(isPresented: $showPreview) {
                if let invoiceId = savedInvoiceId {
                    InvoiceDetailScreen(invoiceId: invoiceId)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallScreen()
            }
        }
    }

    // MARK: - Client Section

    private var clientSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bill To")
                .font(.headline)
            Button { showClientPicker = true } label: {
                HStack {
                    Image(systemName: "person")
                        .foregroundStyle(.secondary)
                    if let client = selectedClient {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.displayName)
                                .foregroundStyle(.primary)
                            if !client.email.isEmpty {
                                Text(client.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("Select Client")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
            DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)

            // Currency
            VStack(alignment: .leading, spacing: 6) {
                Text("Currency").font(.caption).foregroundStyle(.secondary)
                Menu {
                    ForEach(currencies) { c in
                        Button {
                            currency = c.code
                        } label: {
                            HStack {
                                Text("\(c.symbol)  \(c.code) — \(c.name)")
                                if currency == c.code { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let sel = currencies.first(where: { $0.code == currency }) {
                            Text("\(sel.symbol)  \(sel.code) — \(sel.name)")
                                .foregroundStyle(.primary)
                        } else {
                            Text("Select currency").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Language
            VStack(alignment: .leading, spacing: 6) {
                Text("Language").font(.caption).foregroundStyle(.secondary)
                Menu {
                    ForEach(languages) { l in
                        Button {
                            language = l.code
                        } label: {
                            HStack {
                                Text(l.name)
                                if language == l.code { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let sel = languages.first(where: { $0.code == language }) {
                            Text(sel.name).foregroundStyle(.primary)
                        } else {
                            Text("Select language").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Payment terms
            VStack(alignment: .leading, spacing: 6) {
                Text("Payment Terms").font(.caption).foregroundStyle(.secondary)
                TextField("e.g. Net 30, Due on Receipt", text: $paymentTerms)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Items")
                    .font(.headline)
                Spacer()
                if items.count < maxInvoiceItems {
                    Button { showAddItem = true } label: {
                        Label("Add", systemImage: "plus")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                } else {
                    Text("Max \(maxInvoiceItems) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if items.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "cart")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No items yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Tap \"Add\" to add a line item")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.body)
                                .lineLimit(1)
                            if !item.description.isEmpty {
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Text("\(formatQty(item.quantity)) × \(currencySymbol)\(formatPrice(item.unitPrice))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(currencySymbol)\(formatPrice(item.amount))")
                            .font(.body)
                            .fontWeight(.medium)
                        Button {
                            items.removeAll { $0.id == item.id }
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Tax & Discount

    private var taxDiscountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tax & Discount")
                .font(.headline)

            HStack {
                Text("Tax Rate").font(.caption).foregroundStyle(.secondary)
                Spacer()
                TextField("0.00", text: $taxRate)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("%").foregroundStyle(.secondary)
            }

            Toggle("Tax Inclusive", isOn: $taxInclusive)

            VStack(alignment: .leading, spacing: 6) {
                Text("Discount").font(.caption).foregroundStyle(.secondary)
                Picker("Discount", selection: $discountType) {
                    Text("None").tag("none")
                    Text("Percentage").tag("percent")
                    Text("Fixed Amount").tag("fixed")
                }
                .pickerStyle(.segmented)
            }

            if discountType != "none" {
                HStack {
                    TextField("0", text: $discountValue)
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(discountType == "percent" ? "%" : currencySymbol)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                }
            }
        }
    }

    // MARK: - Totals

    private var totalsSection: some View {
        VStack(spacing: 8) {
            totalRow("Subtotal", value: subtotal)
            if discountAmount > 0 {
                totalRow("Discount", value: -discountAmount, color: .green)
            }
            if (Double(taxRate) ?? 0) > 0 {
                totalRow("Tax (\(taxRate)%)", value: taxAmount)
            }
            Divider()
            HStack {
                Text("Total").font(.title3).fontWeight(.bold)
                Spacer()
                Text("\(currencySymbol)\(formatPrice(total))")
                    .font(.title3).fontWeight(.bold)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func totalRow(_ label: String, value: Double, color: Color = .primary) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text("\(currencySymbol)\(formatPrice(value))")
                .font(.subheadline).foregroundStyle(color)
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes").font(.headline)
            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Payment instructions, thank you message...")
                            .foregroundStyle(.tertiary)
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Formatters

    private func formatPrice(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func formatQty(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value) : String(format: "%.2f", value)
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    // MARK: - Load Form Data

    private func loadFormData() async {
        do {
            async let currReq = APIClient.shared.request(
                [Currency].self, method: "GET", path: "/invoices/currencies/"
            )
            async let langReq = APIClient.shared.request(
                [Language].self, method: "GET", path: "/invoices/languages/"
            )
            async let clientReq = APIClient.shared.request(
                [Client].self, method: "GET", path: "/accounts/clients/"
            )
            async let profileReq = APIClient.shared.request(
                [BusinessProfile].self, method: "GET", path: "/accounts/business-profiles/"
            )

            let (fetchedCurr, fetchedLang, fetchedClients, profiles) =
                try await (currReq, langReq, clientReq, profileReq)

            await MainActor.run {
                currencies = fetchedCurr
                languages = fetchedLang
                clients = fetchedClients

                // Pre-fill from business profile defaults
                if let profile = profiles.first {
                    templateSlug = profile.defaultTemplate
                    currency = profile.defaultCurrency
                    language = profile.defaultLanguage
                    taxRate = profile.defaultTaxRate
                    paymentTerms = profile.defaultPaymentTerms
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

    // MARK: - Build API Body
    // Must match what Django invoices view expects:
    // Required: issue_date, due_date, items[]
    // Optional: client_id, template_slug, language, currency,
    //           payment_terms, notes, tax_rate, tax_inclusive,
    //           discount_type, discount_value

    private func buildBody() -> [String: Any] {
        var body: [String: Any] = [
            "template_slug": templateSlug,
            "language": language,
            "currency": currency,
            "issue_date": dateFormatter.string(from: issueDate),
            "due_date": dateFormatter.string(from: dueDate),
            "payment_terms": paymentTerms,
            "notes": notes,
            "tax_rate": taxRate.isEmpty ? "0" : taxRate,
            "tax_inclusive": taxInclusive,
            "discount_type": discountType,
            "discount_value": discountValue.isEmpty ? "0" : discountValue,
            "items": items.enumerated().map { index, item in
                [
                    "name": item.name,
                    "description": item.description,
                    "quantity": String(item.quantity),
                    "unit_price": String(item.unitPrice),
                    "sort_order": index,
                ] as [String: Any]
            }
        ]

        if let client = selectedClient {
            body["client_id"] = client.publicId
        }

        return body
    }

    // MARK: - Save Invoice (shared logic for draft + preview)

    private func saveInvoice() async throws -> Invoice {
        if let existingId = savedInvoiceId {
            return try await APIClient.shared.request(
                Invoice.self, method: "GET",
                path: "/invoices/\(existingId)/"
            )
        }

        do {
            let result = try await APIClient.shared.request(
                Invoice.self, method: "POST",
                path: "/invoices/", body: buildBody()
            )
            await MainActor.run { savedInvoiceId = result.publicId }
            return result
        } catch let error as APIError {
            // If limit reached, show paywall instead of error
            if case .limitReached = error {
                await MainActor.run {
                    isSaving = false
                    showPaywall = true
                }
                throw error
            }
            throw error
        }
    }

    // MARK: - Save Draft (saves and closes)

    private func saveDraft() {
        guard savedInvoiceId == nil else {
            isPresented = false
            return
        }
        isSaving = true
        errorMessage = ""
        Task {
            do {
                let _ = try await saveInvoice()
                await MainActor.run {
                    isSaving = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Failed to save"
                    isSaving = false
                }
            }
        }
    }

    // MARK: - Save and Preview (saves then navigates to detail)

    private func saveAndPreview() {
        if savedInvoiceId != nil {
            showPreview = true
            return
        }
        isSaving = true
        errorMessage = ""
        Task {
            do {
                let _ = try await saveInvoice()
                await MainActor.run {
                    isSaving = false
                    showPreview = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Failed to save"
                    isSaving = false
                }
            }
        }
    }
}
