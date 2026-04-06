// Screens/ClientPickerSheet.swift
// Bottom sheet to select an existing client or create a new one inline.
// Used from CreateInvoiceScreen.
import SwiftUI

struct ClientPickerSheet: View {
    @Binding var clients: [Client]
    @Binding var selected: Client?
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var showNewClient = false

    // New client form
    @State private var newCompanyName = ""
    @State private var newContactName = ""
    @State private var newEmail = ""
    @State private var newPhone = ""
    @State private var isSaving = false
    @State private var errorMessage = ""

    private var filteredClients: [Client] {
        if searchText.isEmpty { return clients }
        let q = searchText.lowercased()
        return clients.filter {
            $0.companyName.lowercased().contains(q) ||
            $0.contactName.lowercased().contains(q) ||
            $0.email.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
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

                // New client button / form
                if showNewClient {
                    newClientForm
                        .padding(16)
                } else {
                    Button {
                        withAnimation { showNewClient = true }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                            Text("New Client")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                Divider()
                    .padding(.top, 8)

                // Client list
                if filteredClients.isEmpty {
                    VStack(spacing: 8) {
                        Text("No clients found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if !searchText.isEmpty {
                            Text("Try a different search or create a new client.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.top, 40)
                    Spacer()
                } else {
                    List(filteredClients) { client in
                        Button {
                            selected = client
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(client.displayName)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if !client.email.isEmpty {
                                        Text(client.email)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selected?.publicId == client.publicId {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - New Client Inline Form

    private var newClientForm: some View {
        VStack(spacing: 12) {
            Text("New Client")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Company name", text: $newCompanyName)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                TextField("Contact name", text: $newContactName)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                TextField("Email", text: $newEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                TextField("Phone", text: $newPhone)
                    .keyboardType(.phonePad)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    withAnimation { showNewClient = false }
                }
                .foregroundStyle(.secondary)

                ButtonPrimary(
                    title: "Save & Select",
                    isLoading: isSaving,
                    isDisabled: newCompanyName.isEmpty && newContactName.isEmpty
                ) {
                    saveNewClient()
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Save New Client

    private func saveNewClient() {
        isSaving = true
        errorMessage = ""
        let body: [String: Any] = [
            "company_name": newCompanyName,
            "contact_name": newContactName,
            "email": newEmail,
            "phone": newPhone,
        ]
        Task {
            do {
                let client = try await APIClient.shared.request(
                    Client.self,
                    method: "POST",
                    path: "/accounts/clients/",
                    body: body
                )
                await MainActor.run {
                    clients.insert(client, at: 0)
                    selected = client
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Failed to create client"
                    isSaving = false
                }
            }
        }
    }
}
