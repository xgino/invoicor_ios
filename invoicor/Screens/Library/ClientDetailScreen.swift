// Screens/Library/ClientDetailScreen.swift
// Client detail with stats, invoice history, and editable profile.
// Uses SubPageLayout for full-page experience — no default nav bar.

import SwiftUI

struct ClientDetailScreen: View {
    let clientId: String
    let allInvoices: [Invoice]

    @Environment(\.dismiss) private var dismiss
    @State private var client: Client? = nil
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var showDeleteConfirm = false

    // Edit fields
    @State private var companyName = ""
    @State private var contactName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var addressLine1 = ""
    @State private var addressLine2 = ""
    @State private var city = ""
    @State private var stateField = ""
    @State private var postalCode = ""
    @State private var country = ""
    @State private var taxId = ""
    @State private var notes = ""

    private var clientInvoices: [Invoice] {
        guard let c = client else { return [] }
        return allInvoices.filter { inv in
            (inv.clientSnapshot["company_name"]?.stringValue == c.companyName && !c.companyName.isEmpty) ||
            (inv.clientSnapshot["contact_name"]?.stringValue == c.contactName && !c.contactName.isEmpty) ||
            (inv.clientSnapshot["email"]?.stringValue == c.email && !c.email.isEmpty)
        }
    }

    private var totalPaid: Double {
        clientInvoices.filter { $0.status == "paid" }.compactMap { Double($0.total) }.reduce(0, +)
    }
    private var outstanding: Double {
        clientInvoices.filter { $0.status == "sent" || $0.status == "overdue" }.compactMap { Double($0.total) }.reduce(0, +)
    }

    var body: some View {
        SubPageLayout(
            title: client?.displayName ?? "Client",
            trailingButton: AnyView(
                Button { isEditing ? saveClient() : toggleEdit() } label: {
                    Text("Edit")
                }
            ),
            onBack: { dismiss() }
        ) {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
            } else {
                clientHeader
                statsRow
                invoiceHistory

                if isEditing {
                    editableDetails
                } else {
                    readOnlyDetails
                }

                if !errorMessage.isEmpty { InlineBanner(message: errorMessage, style: .error) }
                if !successMessage.isEmpty { InlineBanner(message: successMessage, style: .success) }

                if clientInvoices.isEmpty && !isEditing {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        HStack(spacing: 8) { Image(systemName: "trash"); Text("Delete Client") }
                            .font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                }
            }
        }
        .task { await loadClient() }
        .alert("Delete Client?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteClient() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This will permanently delete this client.") }
    }

    // MARK: - Header

    private var clientHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(avatarColor)
                Text(avatarInitials).font(.title2.weight(.bold)).foregroundStyle(.white)
            }.frame(width: 56, height: 56)

            Text(client?.displayName ?? "").font(.title3.weight(.bold))
            if let c = client, !c.email.isEmpty {
                Text(c.email).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity).padding(.bottom, 4)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            miniStat("Lifetime", "$\(String(format: "%.0f", totalPaid))", color: .green)
            miniStat("Outstanding", outstanding > 0 ? "$\(String(format: "%.0f", outstanding))" : "—", color: outstanding > 0 ? .orange : .secondary)
            miniStat("Invoices", "\(clientInvoices.count)", color: .blue)
        }
    }

    private func miniStat(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.weight(.semibold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10).background(Color(.systemGray6).opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Invoice History

    private var invoiceHistory: some View {
        FormSection(title: "Invoices") {
            if clientInvoices.isEmpty {
                Text("No invoices with this client yet.").font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                ForEach(clientInvoices) { invoice in
                    NavigationLink {
                        InvoiceDetailScreen(invoiceId: invoice.publicId)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(invoice.invoiceNumber).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                                Text(invoice.issueDate).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(invoice.totalFormatted).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                                StatusBadge(status: invoice.status)
                            }
                        }.padding(.vertical, 4)
                    }
                    if invoice.id != clientInvoices.last?.id { Divider() }
                }
            }
        }
    }

    // MARK: - Read-Only Details

    private var readOnlyDetails: some View {
        FormSection(title: "Details") {
            detailRow("Company", companyName)
            detailRow("Contact", contactName)
            detailRow("Email", email)
            detailRow("Phone", phone)
            detailRow("Address", [addressLine1, addressLine2, city, stateField, postalCode, country].filter { !$0.isEmpty }.joined(separator: ", "))
            detailRow("Tax ID", taxId)
            if !notes.isEmpty { detailRow("Notes", notes) }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        Group {
            if !value.isEmpty {
                HStack(alignment: .top) {
                    Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                    Text(value).font(.subheadline)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Editable Details

    private var editableDetails: some View {
        VStack(spacing: 16) {
            FormSection(title: "Identity") {
                StyledFormField("Company Name", text: $companyName, placeholder: "Company name")
                StyledFormField("Contact Name", text: $contactName, placeholder: "Contact person")
            }
            FormSection(title: "Contact") {
                StyledFormField("Email", text: $email, placeholder: "email@company.com", keyboard: .emailAddress, autocap: .never)
                StyledFormField("Phone", text: $phone, placeholder: "+31 6 1234 5678", keyboard: .phonePad)
            }
            FormSection(title: "Address") {
                StyledFormField("Address Line 1", text: $addressLine1, placeholder: "Street")
                StyledFormField("Address Line 2", text: $addressLine2, placeholder: "Suite, floor")
                HStack(spacing: 12) {
                    StyledFormField("City", text: $city, placeholder: "City")
                    StyledFormField("State", text: $stateField, placeholder: "State")
                }
                HStack(spacing: 12) {
                    StyledFormField("Postal Code", text: $postalCode, placeholder: "Code")
                    StyledFormField("Country", text: $country, placeholder: "Country")
                }
            }
            FormSection(title: "Tax & Notes") {
                StyledFormField("Tax ID", text: $taxId, placeholder: "e.g. NL123456789B01")
                FormTextEditor(label: "Notes", text: $notes, placeholder: "Internal notes", minHeight: 60)
            }
        }
    }

    // MARK: - Helpers

    private func toggleEdit() { isEditing = true }

    private var avatarInitials: String {
        let name = client?.displayName ?? "?"
        let words = name.split(separator: " ")
        if words.count >= 2 { return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo]
        return colors[abs((client?.displayName ?? "").hashValue) % colors.count]
    }

    // MARK: - Load / Save / Delete

    private func loadClient() async {
        do {
            let c = try await APIClient.shared.request(Client.self, method: "GET", path: "/accounts/clients/\(clientId)/")
            await MainActor.run {
                client = c
                companyName = c.companyName; contactName = c.contactName
                email = c.email; phone = c.phone
                addressLine1 = c.addressLine1; addressLine2 = c.addressLine2
                city = c.city; stateField = c.state
                postalCode = c.postalCode; country = c.country
                taxId = c.taxId; notes = c.notes
                isLoading = false
            }
        } catch {
            await MainActor.run { errorMessage = (error as? APIError)?.errorDescription ?? "Failed to load"; isLoading = false }
        }
    }

    private func saveClient() {
        isSaving = true; errorMessage = ""; successMessage = ""
        let body: [String: Any] = [
            "company_name": companyName, "contact_name": contactName,
            "email": email, "phone": phone,
            "address_line_1": addressLine1, "address_line_2": addressLine2,
            "city": city, "state": stateField, "postal_code": postalCode, "country": country,
            "tax_id": taxId, "notes": notes,
        ]
        Task {
            do {
                let updated = try await APIClient.shared.request(Client.self, method: "PUT", path: "/accounts/clients/\(clientId)/", body: body)
                await MainActor.run {
                    client = updated; isSaving = false; isEditing = false
                    withAnimation { successMessage = "Client saved" }
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { withAnimation { successMessage = "" } }
            } catch {
                await MainActor.run { errorMessage = (error as? APIError)?.errorDescription ?? "Failed to save"; isSaving = false }
            }
        }
    }

    private func deleteClient() {
        Task {
            try? await APIClient.shared.requestNoContent(method: "DELETE", path: "/accounts/clients/\(clientId)/")
            await MainActor.run { dismiss() }
        }
    }
}
