// Screens/Library/ClientFormSheet.swift
// Sheet to add or edit a client. Matches ProductFormSheet pattern.
// Used from LibraryScreen and ClientPickerSheet.

import SwiftUI

struct ClientFormSheet: View {
    @Binding var clients: [Client]
    let editing: Client?
    @Environment(\.dismiss) private var dismiss

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
    @State private var isSaving = false
    @State private var errorMessage = ""

    private var isValid: Bool { !companyName.isEmpty || !contactName.isEmpty }
    private var isEditing: Bool { editing != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    FormSection(title: "Identity", footer: "Company name, contact name, or both.") {
                        StyledFormField("Company Name", text: $companyName, placeholder: "Company or business name")
                        StyledFormField("Contact Name", text: $contactName, placeholder: "Person's full name")
                    }

                    FormSection(title: "Contact") {
                        StyledFormField("Email", text: $email, placeholder: "client@email.com", keyboard: .emailAddress, autocap: .never)
                        StyledFormField("Phone", text: $phone, placeholder: "+31 6 1234 5678", keyboard: .phonePad)
                    }

                    FormSection(title: "Address") {
                        StyledFormField("Address Line 1", text: $addressLine1, placeholder: "Street and number")
                        StyledFormField("Address Line 2", text: $addressLine2, placeholder: "Suite, building, floor")
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
                        FormTextEditor(label: "Notes", text: $notes, placeholder: "Internal notes about this client", minHeight: 60)
                    }

                    if !errorMessage.isEmpty { InlineBanner(message: errorMessage, style: .error) }

                    ButtonPrimary(
                        title: isEditing ? "Save Changes" : "Add Client",
                        isLoading: isSaving, isDisabled: !isValid
                    ) { saveClient() }

                    if isEditing {
                        Button(role: .destructive) { deleteAndDismiss() } label: {
                            HStack(spacing: 8) { Image(systemName: "trash"); Text("Delete Client") }
                                .font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(isEditing ? "Edit Client" : "New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                if let c = editing {
                    companyName = c.companyName; contactName = c.contactName
                    email = c.email; phone = c.phone
                    addressLine1 = c.addressLine1; addressLine2 = c.addressLine2
                    city = c.city; stateField = c.state
                    postalCode = c.postalCode; country = c.country
                    taxId = c.taxId; notes = c.notes
                }
            }
        }
    }

    private func saveClient() {
        isSaving = true; errorMessage = ""
        let body: [String: Any] = [
            "company_name": companyName, "contact_name": contactName,
            "email": email, "phone": phone,
            "address_line_1": addressLine1, "address_line_2": addressLine2,
            "city": city, "state": stateField,
            "postal_code": postalCode, "country": country,
            "tax_id": taxId, "notes": notes,
        ]
        Task {
            do {
                if let existing = editing {
                    let updated = try await APIClient.shared.request(
                        Client.self, method: "PUT", path: "/accounts/clients/\(existing.publicId)/", body: body
                    )
                    await MainActor.run {
                        if let idx = clients.firstIndex(where: { $0.publicId == existing.publicId }) { clients[idx] = updated }
                        isSaving = false; dismiss()
                    }
                } else {
                    let created = try await APIClient.shared.request(
                        Client.self, method: "POST", path: "/accounts/clients/", body: body
                    )
                    await MainActor.run { clients.insert(created, at: 0); isSaving = false; dismiss() }
                }
            } catch {
                await MainActor.run { errorMessage = (error as? APIError)?.errorDescription ?? "Failed to save"; isSaving = false }
            }
        }
    }

    private func deleteAndDismiss() {
        guard let existing = editing else { return }
        Task {
            try? await APIClient.shared.requestNoContent(method: "DELETE", path: "/accounts/clients/\(existing.publicId)/")
            await MainActor.run { clients.removeAll { $0.publicId == existing.publicId }; dismiss() }
        }
    }
}
