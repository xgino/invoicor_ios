// Screens/Library/ProductFormSheet.swift
// Sheet to add or edit a saved product. Used from LibraryScreen.
// Uses shared form components for consistent styling.

import SwiftUI

struct ProductFormSheet: View {
    @Binding var products: [Product]
    let editing: Product?
    let currencySymbol: String
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var defaultPrice = ""
    @State private var isSaving = false
    @State private var errorMessage = ""

    private var isValid: Bool { !name.isEmpty }
    private var isEditing: Bool { editing != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    FormSection(title: "Details") {
                        StyledFormField("Product Name", text: $name, placeholder: "e.g. Website Design, Consulting Hour")
                        StyledFormField("Description", text: $description, placeholder: "What this product/service includes")
                    }

                    FormSection(title: "Pricing") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Default Price").font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Text(currencySymbol).foregroundStyle(.secondary).fontWeight(.medium)
                                TextField("0.00", text: $defaultPrice)
                                    .keyboardType(.decimalPad)
                                    .padding(.horizontal, 12).padding(.vertical, 10)
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 0.5))
                            }
                        }
                    }

                    if !errorMessage.isEmpty {
                        InlineBanner(message: errorMessage, style: .error)
                    }

                    ButtonPrimary(
                        title: isEditing ? "Save Changes" : "Add Product",
                        isLoading: isSaving, isDisabled: !isValid
                    ) { saveProduct() }

                    if isEditing {
                        Button(role: .destructive) { deleteAndDismiss() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash"); Text("Delete Product")
                            }
                            .font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(isEditing ? "Edit Product" : "New Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let p = editing {
                    name = p.name; description = p.description; defaultPrice = p.defaultPrice
                }
            }
        }
    }

    private func saveProduct() {
        isSaving = true; errorMessage = ""
        let body: [String: Any] = [
            "name": name, "description": description,
            "default_price": defaultPrice.isEmpty ? "0" : defaultPrice,
        ]
        Task {
            do {
                if let existing = editing {
                    let updated = try await APIClient.shared.request(
                        Product.self, method: "PUT",
                        path: "/invoices/products/\(existing.publicId)/", body: body
                    )
                    await MainActor.run {
                        if let idx = products.firstIndex(where: { $0.publicId == existing.publicId }) { products[idx] = updated }
                        isSaving = false; dismiss()
                    }
                } else {
                    let created = try await APIClient.shared.request(
                        Product.self, method: "POST", path: "/invoices/products/", body: body
                    )
                    await MainActor.run {
                        products.insert(created, at: 0); isSaving = false; dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Failed to save"
                    isSaving = false
                }
            }
        }
    }

    private func deleteAndDismiss() {
        guard let existing = editing else { return }
        Task {
            try? await APIClient.shared.requestNoContent(method: "DELETE", path: "/invoices/products/\(existing.publicId)/")
            await MainActor.run { products.removeAll { $0.publicId == existing.publicId }; dismiss() }
        }
    }
}
