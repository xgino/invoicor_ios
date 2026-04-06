// Screens/ClientDetailScreen.swift
// Client insights screen: LTV, outstanding, invoice history, editable profile.
// Makes the Clients tab valuable — see who your best customers are.
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

    // Client invoices filtered from all invoices
    private var clientInvoices: [Invoice] {
        guard let c = client else { return [] }
        return allInvoices.filter { inv in
            (inv.clientSnapshot["company_name"]?.stringValue == c.companyName && !c.companyName.isEmpty) ||
            (inv.clientSnapshot["contact_name"]?.stringValue == c.contactName && !c.contactName.isEmpty) ||
            (inv.clientSnapshot["email"]?.stringValue == c.email && !c.email.isEmpty)
        }
    }

    // Stats
    private var totalPaid: Double {
        clientInvoices
            .filter { $0.status == "paid" }
            .compactMap { Double($0.total) }
            .reduce(0, +)
    }

    private var outstanding: Double {
        clientInvoices
            .filter { $0.status == "sent" || $0.status == "overdue" }
            .compactMap { Double($0.total) }
            .reduce(0, +)
    }

    private var overdueCount: Int {
        clientInvoices.filter { $0.status == "overdue" }.count
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    // Client header
                    clientHeader

                    // Stats cards
                    statsSection

                    // Invoice history
                    invoiceHistorySection

                    // Profile details (editable)
                    profileSection

                    // Delete button
                    if clientInvoices.isEmpty {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Client")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !isLoading {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            saveClient()
                        } else {
                            isEditing = true
                        }
                    }
                    .fontWeight(.medium)
                }
            }
        }
        .task { await loadClient() }
        .alert("Delete Client?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteClient() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this client.")
        }
    }

    // MARK: - Client Header

    private var clientHeader: some View {
        VStack(spacing: 8) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor)
                Text(avatarInitials)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)

            Text(client?.displayName ?? "")
                .font(.title3)
                .fontWeight(.bold)

            if let c = client, !c.email.isEmpty {
                Text(c.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Lifetime Value",
                value: "$\(String(format: "%.2f", totalPaid))",
                color: .green
            )
            statCard(
                title: "Outstanding",
                value: outstanding > 0 ? "$\(String(format: "%.2f", outstanding))" : "—",
                color: outstanding > 0 ? .orange : .secondary
            )
            statCard(
                title: "Invoices",
                value: "\(clientInvoices.count)",
                color: .blue
            )
        }
        .padding(.horizontal, 16)
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Invoice History

    private var invoiceHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invoice History")
                .font(.headline)
                .padding(.horizontal, 16)

            if clientInvoices.isEmpty {
                Text("No invoices with this client yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            } else {
                ForEach(clientInvoices) { invoice in
                    NavigationLink {
                        InvoiceDetailScreen(invoiceId: invoice.publicId)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(invoice.invoiceNumber)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text(invoice.issueDate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(invoice.totalFormatted)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                StatusBadge(status: invoice.status)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    Divider().padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Profile Section (Editable)

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Client Details")
                .font(.headline)
                .padding(.horizontal, 16)

            VStack(spacing: 12) {
                profileRow("Company", text: $companyName, editable: isEditing)
                profileRow("Contact", text: $contactName, editable: isEditing)
                profileRow("Email", text: $email, editable: isEditing, keyboard: .emailAddress)
                profileRow("Phone", text: $phone, editable: isEditing, keyboard: .phonePad)
                profileRow("Address", text: $addressLine1, editable: isEditing)
                profileRow("City", text: $city, editable: isEditing)
                profileRow("Country", text: $country, editable: isEditing)
                profileRow("Tax ID", text: $taxId, editable: isEditing)
                profileRow("Notes", text: $notes, editable: isEditing)
            }
            .padding(.horizontal, 16)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
            }
        }
    }

    private func profileRow(
        _ label: String, text: Binding<String>,
        editable: Bool, keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            if editable {
                TextField(label, text: text)
                    .keyboardType(keyboard)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text(text.wrappedValue.isEmpty ? "—" : text.wrappedValue)
                    .font(.subheadline)
                Spacer()
            }
        }
    }

    // MARK: - Avatar Helpers

    private var avatarInitials: String {
        guard let c = client else { return "?" }
        let name = c.displayName
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var avatarColor: Color {
        let name = client?.displayName ?? ""
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo]
        return colors[abs(name.hashValue) % colors.count]
    }

    // MARK: - Load Client

    private func loadClient() async {
        do {
            let c = try await APIClient.shared.request(
                Client.self, method: "GET",
                path: "/accounts/clients/\(clientId)/"
            )
            await MainActor.run {
                client = c
                companyName = c.companyName
                contactName = c.contactName
                email = c.email
                phone = c.phone
                addressLine1 = c.addressLine1
                addressLine2 = c.addressLine2
                city = c.city
                stateField = c.state
                postalCode = c.postalCode
                country = c.country
                taxId = c.taxId
                notes = c.notes
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Failed to load"
                isLoading = false
            }
        }
    }

    // MARK: - Save Client

    private func saveClient() {
        isSaving = true
        errorMessage = ""
        let body: [String: Any] = [
            "company_name": companyName,
            "contact_name": contactName,
            "email": email,
            "phone": phone,
            "address_line_1": addressLine1,
            "address_line_2": addressLine2,
            "city": city,
            "state": stateField,
            "postal_code": postalCode,
            "country": country,
            "tax_id": taxId,
            "notes": notes,
        ]
        Task {
            do {
                let updated = try await APIClient.shared.request(
                    Client.self, method: "PUT",
                    path: "/accounts/clients/\(clientId)/", body: body
                )
                await MainActor.run {
                    client = updated
                    isSaving = false
                    isEditing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Failed to save"
                    isSaving = false
                }
            }
        }
    }

    // MARK: - Delete Client

    private func deleteClient() {
        Task {
            do {
                try await APIClient.shared.requestNoContent(
                    method: "DELETE",
                    path: "/accounts/clients/\(clientId)/"
                )
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Failed to delete"
                }
            }
        }
    }
}
