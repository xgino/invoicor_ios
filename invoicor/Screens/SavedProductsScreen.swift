// Screens/SavedProductsScreen.swift
// Manage saved products/services. Create, edit, delete.
// These pre-fill invoice line items for faster invoicing.
import SwiftUI

struct SavedProductsScreen: View {
    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showAddProduct = false
    @State private var editingProduct: Product? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if products.isEmpty {
                EmptyState(
                    icon: "archivebox",
                    title: "No saved products",
                    message: "Save your frequently used services and products here for faster invoicing.",
                    buttonTitle: "Add Product"
                ) {
                    showAddProduct = true
                }
            } else {
                List {
                    ForEach(products) { product in
                        Button {
                            editingProduct = product
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(product.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    if !product.description.isEmpty {
                                        Text(product.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                Text(product.defaultPrice)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteProduct(product)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Saved Products")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddProduct = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await loadProducts() }
        .refreshable { await loadProducts() }
        .sheet(isPresented: $showAddProduct) {
            ProductFormSheet(products: $products, editing: nil)
        }
        .sheet(item: $editingProduct) { product in
            ProductFormSheet(products: $products, editing: product)
        }
    }

    private func deleteProduct(_ product: Product) {
        Task {
            try? await APIClient.shared.requestNoContent(
                method: "DELETE",
                path: "/invoices/products/\(product.publicId)/"
            )
            await MainActor.run {
                products.removeAll { $0.publicId == product.publicId }
            }
        }
    }

    private func loadProducts() async {
        isLoading = products.isEmpty
        do {
            let fetched = try await APIClient.shared.request(
                [Product].self, method: "GET", path: "/invoices/products/"
            )
            await MainActor.run {
                products = fetched
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

// MARK: - Product Form (Add / Edit)

struct ProductFormSheet: View {
    @Binding var products: [Product]
    let editing: Product?  // nil = new, set = editing
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var defaultPrice = ""
    @State private var isSaving = false
    @State private var errorMessage = ""

    private var isValid: Bool {
        !name.isEmpty
    }

    private var isEditing: Bool { editing != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Product Name *")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("e.g. Website Design, Consulting Hour", text: $name)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("What this product/service includes", text: $description)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Default Price")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("0.00", text: $defaultPrice)
                            .keyboardType(.decimalPad)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    ButtonPrimary(
                        title: isEditing ? "Save Changes" : "Add Product",
                        isLoading: isSaving,
                        isDisabled: !isValid
                    ) {
                        saveProduct()
                    }
                    .padding(.top, 8)

                    // Delete button for editing
                    if isEditing {
                        Button(role: .destructive) {
                            deleteAndDismiss()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Product")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    }

                    Spacer()
                }
                .padding(24)
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
                    name = p.name
                    description = p.description
                    defaultPrice = p.defaultPrice
                }
            }
        }
    }

    private func saveProduct() {
        isSaving = true
        errorMessage = ""
        let body: [String: Any] = [
            "name": name,
            "description": description,
            "default_price": defaultPrice.isEmpty ? "0" : defaultPrice,
        ]
        Task {
            do {
                if let existing = editing {
                    // Update
                    let updated = try await APIClient.shared.request(
                        Product.self, method: "PUT",
                        path: "/invoices/products/\(existing.publicId)/",
                        body: body
                    )
                    await MainActor.run {
                        if let idx = products.firstIndex(where: { $0.publicId == existing.publicId }) {
                            products[idx] = updated
                        }
                        isSaving = false
                        dismiss()
                    }
                } else {
                    // Create
                    let created = try await APIClient.shared.request(
                        Product.self, method: "POST",
                        path: "/invoices/products/",
                        body: body
                    )
                    await MainActor.run {
                        products.insert(created, at: 0)
                        isSaving = false
                        dismiss()
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
            try? await APIClient.shared.requestNoContent(
                method: "DELETE",
                path: "/invoices/products/\(existing.publicId)/"
            )
            await MainActor.run {
                products.removeAll { $0.publicId == existing.publicId }
                dismiss()
            }
        }
    }
}
