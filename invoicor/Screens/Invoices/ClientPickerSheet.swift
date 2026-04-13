// Screens/ClientPickerSheet.swift
// Bottom sheet to select an existing client or create a new one inline.
// Uses shared form components for consistent styling.

import SwiftUI

struct ClientPickerSheet: View {
    @Binding var clients: [Client]
    @Binding var selected: Client?
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var showNewClient = false
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
                // Search
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search clients…", text: $searchText).autocorrectionDisabled()
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16).padding(.top, 8)

                // New client toggle
                if showNewClient {
                    newClientForm.padding(16)
                } else {
                    Button {
                        withAnimation { showNewClient = true }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill").foregroundStyle(.blue)
                            Text("New Client").fontWeight(.medium)
                            Spacer()
                        }
                        .padding(12)
                    }
                    .padding(.horizontal, 16).padding(.top, 8)
                }

                Divider().padding(.top, 8)

                // Client list
                if filteredClients.isEmpty {
                    VStack(spacing: 8) {
                        Text("No clients found").font(.subheadline).foregroundStyle(.secondary)
                        if !searchText.isEmpty {
                            Text("Try a different search or create a new client.")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.top, 40)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filteredClients) { client in
                                Button {
                                    selected = client
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "person.circle.fill")
                                            .font(.title3).foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(client.displayName)
                                                .font(.body).foregroundStyle(.primary)
                                            if !client.email.isEmpty {
                                                Text(client.email)
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if selected?.publicId == client.publicId {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    .padding(.vertical, 12).padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)
                                if client.id != filteredClients.last?.id {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                    }
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

    // MARK: - New Client Form

    private var newClientForm: some View {
        VStack(spacing: 12) {
            HStack {
                Text("New Client").font(.subheadline.weight(.semibold))
                Spacer()
                Button { withAnimation { showNewClient = false } } label: {
                    Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
                }
            }

            StyledFormField("Company Name", text: $newCompanyName, placeholder: "Company name")
            StyledFormField("Contact Name", text: $newContactName, placeholder: "Contact person")
            StyledFormField("Email", text: $newEmail, placeholder: "client@email.com", keyboard: .emailAddress, autocap: .never)
            StyledFormField("Phone", text: $newPhone, placeholder: "+1 555 1234", keyboard: .phonePad)

            if !errorMessage.isEmpty {
                InlineBanner(message: errorMessage, style: .error)
            }

            ButtonPrimary(
                title: "Save & Select",
                isLoading: isSaving,
                isDisabled: newCompanyName.isEmpty && newContactName.isEmpty
            ) {
                saveNewClient()
            }
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func saveNewClient() {
        isSaving = true
        errorMessage = ""
        Task {
            do {
                let client = try await APIClient.shared.request(
                    Client.self, method: "POST", path: "/accounts/clients/",
                    body: [
                        "company_name": newCompanyName, "contact_name": newContactName,
                        "email": newEmail, "phone": newPhone,
                    ]
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
