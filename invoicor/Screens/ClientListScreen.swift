// Screens/ClientListScreen.swift
// Tab 4: Client list with search + LTV preview per client.
// Shows lifetime value from invoice data to make the list useful.
import SwiftUI

struct ClientListScreen: View {
    @State private var clients: [Client] = []
    @State private var invoices: [Invoice] = []
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var searchText = ""
    @State private var showAddClient = false

    private var filteredClients: [Client] {
        if searchText.isEmpty { return clients }
        let q = searchText.lowercased()
        return clients.filter {
            $0.companyName.lowercased().contains(q) ||
            $0.contactName.lowercased().contains(q) ||
            $0.email.lowercased().contains(q)
        }
    }

    // Calculate stats per client from invoice data
    private func clientStats(for client: Client) -> (invoiceCount: Int, totalPaid: Double, outstanding: Double) {
        let clientInvoices = invoices.filter { inv in
            inv.clientSnapshot["company_name"]?.stringValue == client.companyName &&
            !client.companyName.isEmpty ||
            inv.clientSnapshot["contact_name"]?.stringValue == client.contactName &&
            !client.contactName.isEmpty
        }
        let count = clientInvoices.count
        let paid = clientInvoices
            .filter { $0.status == "paid" }
            .compactMap { Double($0.total) }
            .reduce(0, +)
        let outstanding = clientInvoices
            .filter { $0.status == "sent" || $0.status == "overdue" }
            .compactMap { Double($0.total) }
            .reduce(0, +)
        return (count, paid, outstanding)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search clients...", text: $searchText)
                    .autocorrectionDisabled()
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredClients.isEmpty {
                EmptyState(
                    icon: "person.2",
                    title: searchText.isEmpty ? "No clients yet" : "No results",
                    message: searchText.isEmpty
                        ? "Add your first client to start invoicing."
                        : "Try a different search term.",
                    buttonTitle: searchText.isEmpty ? "Add Client" : nil
                ) {
                    showAddClient = true
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredClients) { client in
                        NavigationLink {
                            ClientDetailScreen(
                                clientId: client.publicId,
                                allInvoices: invoices
                            )
                        } label: {
                            clientRow(client)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Clients")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddClient = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await loadData() }
        .refreshable { await loadData() }
        .sheet(isPresented: $showAddClient) {
            AddClientSheet(clients: $clients)
        }
    }

    // MARK: - Client Row

    private func clientRow(_ client: Client) -> some View {
        let stats = clientStats(for: client)
        return HStack {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(avatarColor(for: client.displayName))
                Text(avatarInitials(client.displayName))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(client.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if stats.invoiceCount > 0 {
                        Text("\(stats.invoiceCount) invoice\(stats.invoiceCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !client.email.isEmpty {
                        Text(client.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // LTV
            if stats.totalPaid > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.0f", stats.totalPaid))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                    Text("lifetime")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Avatar Helpers

    private func avatarInitials(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }

    // MARK: - Load Data

    private func loadData() async {
        isLoading = clients.isEmpty
        do {
            async let clientReq = APIClient.shared.request(
                [Client].self, method: "GET", path: "/accounts/clients/"
            )
            async let invoiceReq = APIClient.shared.request(
                [Invoice].self, method: "GET", path: "/invoices/"
            )
            let (fetchedClients, fetchedInvoices) = try await (clientReq, invoiceReq)
            await MainActor.run {
                clients = fetchedClients
                invoices = fetchedInvoices
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Failed to load"
                isLoading = false
            }
        }
    }
}

// MARK: - Add Client Sheet

struct AddClientSheet: View {
    @Binding var clients: [Client]
    @Environment(\.dismiss) private var dismiss

    @State private var companyName = ""
    @State private var contactName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var addressLine1 = ""
    @State private var city = ""
    @State private var country = ""
    @State private var taxId = ""
    @State private var isSaving = false
    @State private var errorMessage = ""

    private var isValid: Bool {
        !companyName.isEmpty || !contactName.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    formField("Company Name", text: $companyName, placeholder: "Company or business name")
                    formField("Contact Name", text: $contactName, placeholder: "Person's full name")
                    formField("Email", text: $email, placeholder: "client@email.com", keyboard: .emailAddress)
                    formField("Phone", text: $phone, placeholder: "+31 6 1234 5678", keyboard: .phonePad)
                    formField("Address", text: $addressLine1, placeholder: "Street and number")
                    HStack(spacing: 12) {
                        formField("City", text: $city, placeholder: "City")
                        formField("Country", text: $country, placeholder: "Country")
                    }
                    formField("Tax ID", text: $taxId, placeholder: "e.g. NL123456789B01")

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    ButtonPrimary(
                        title: "Save Client",
                        isLoading: isSaving,
                        isDisabled: !isValid
                    ) {
                        saveClient()
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .navigationTitle("New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func formField(
        _ label: String, text: Binding<String>,
        placeholder: String = "", keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func saveClient() {
        isSaving = true
        errorMessage = ""
        let body: [String: Any] = [
            "company_name": companyName,
            "contact_name": contactName,
            "email": email,
            "phone": phone,
            "address_line_1": addressLine1,
            "city": city,
            "country": country,
            "tax_id": taxId,
        ]
        Task {
            do {
                let client = try await APIClient.shared.request(
                    Client.self, method: "POST",
                    path: "/accounts/clients/", body: body
                )
                await MainActor.run {
                    clients.insert(client, at: 0)
                    isSaving = false
                    dismiss()
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
