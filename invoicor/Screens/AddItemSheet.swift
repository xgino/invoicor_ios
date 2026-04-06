// Screens/AddItemSheet.swift
// Bottom sheet to add a line item to an invoice.
// Two tabs: "Custom" (one-time item) and "Saved" (from saved products).
// Saved products pre-fill the form. Option to save custom items as products.
import SwiftUI

struct AddItemSheet: View {
    let onAdd: (LocalItem) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var activeTab = 0  // 0 = Custom, 1 = Saved

    // Custom item fields
    @State private var name = ""
    @State private var description = ""
    @State private var quantity = "1"
    @State private var unitPrice = ""
    @State private var saveAsProduct = false

    // Saved products
    @State private var products: [Product] = []
    @State private var isLoadingProducts = true
    @State private var searchText = ""
    @State private var isSavingProduct = false

    private var amount: Double {
        (Double(quantity) ?? 0) * (Double(unitPrice) ?? 0)
    }

    private var isValid: Bool {
        !name.isEmpty && (Double(unitPrice) ?? 0) > 0
    }

    private var filteredProducts: [Product] {
        if searchText.isEmpty { return products }
        let q = searchText.lowercased()
        return products.filter {
            $0.name.lowercased().contains(q) ||
            $0.description.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("", selection: $activeTab) {
                    Text("Custom").tag(0)
                    Text("Saved Items").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 4)

                if activeTab == 0 {
                    customItemForm
                } else {
                    savedItemsList
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await loadProducts()
            }
        }
    }

    // MARK: - Custom Item Form

    private var customItemForm: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Item Name *")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("e.g. Website Design, Logo Package", text: $name)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Description
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Optional details", text: $description)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Quantity and Price
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quantity")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("1", text: $quantity)
                            .keyboardType(.decimalPad)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Unit Price")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("0.00", text: $unitPrice)
                            .keyboardType(.decimalPad)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Amount preview
                if amount > 0 {
                    HStack {
                        Text("Amount").foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f", amount))
                            .font(.title3).fontWeight(.semibold)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Save as product toggle
                Toggle(isOn: $saveAsProduct) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Save for later")
                            .font(.subheadline)
                        Text("Add to your saved items for quick reuse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ButtonPrimary(
                    title: saveAsProduct ? "Save & Add Item" : "Add Item",
                    isLoading: isSavingProduct,
                    isDisabled: !isValid
                ) {
                    addCustomItem()
                }

                Spacer()
            }
            .padding(24)
        }
    }

    // MARK: - Saved Items List

    private var savedItemsList: some View {
        VStack(spacing: 0) {
            if products.isEmpty && !isLoadingProducts {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "archivebox")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("No saved items")
                        .font(.headline)
                    Text("Create a custom item and toggle \"Save for later\" to build your product library.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            } else {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search saved items...", text: $searchText)
                        .autocorrectionDisabled()
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if isLoadingProducts {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    List {
                        ForEach(filteredProducts) { product in
                            Button {
                                selectProduct(product)
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
        }
    }

    // MARK: - Actions

    private func addCustomItem() {
        if saveAsProduct {
            isSavingProduct = true
            Task {
                // Save as product first
                let _ = try? await APIClient.shared.request(
                    Product.self,
                    method: "POST",
                    path: "/invoices/products/",
                    body: [
                        "name": name,
                        "description": description,
                        "default_price": unitPrice,
                    ]
                )
                await MainActor.run { isSavingProduct = false }
            }
        }

        let item = LocalItem(
            name: name,
            description: description,
            quantity: Double(quantity) ?? 1,
            unitPrice: Double(unitPrice) ?? 0
        )
        onAdd(item)
        dismiss()
    }

    private func selectProduct(_ product: Product) {
        // Pre-fill the form with product data and switch to custom tab
        name = product.name
        description = product.description
        unitPrice = product.defaultPrice
        quantity = "1"
        activeTab = 0  // Switch to custom tab to review/adjust before adding
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

    // MARK: - Load Products

    private func loadProducts() async {
        do {
            let fetched = try await APIClient.shared.request(
                [Product].self, method: "GET",
                path: "/invoices/products/"
            )
            await MainActor.run {
                products = fetched
                isLoadingProducts = false
            }
        } catch {
            await MainActor.run {
                isLoadingProducts = false
            }
        }
    }
}
