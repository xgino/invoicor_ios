// Screens/AddItemSheet.swift
// Bottom sheet to add a line item to an invoice.
// Two tabs: "Custom" (one-time item) and "Saved" (from saved products).
// Uses shared form components for consistent styling.

import SwiftUI

struct AddItemSheet: View {
    let currencySymbol: String
    let onAdd: (LocalItem) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var activeTab = 0
    @State private var name = ""
    @State private var description = ""
    @State private var quantity = "1"
    @State private var unitPrice = ""
    @State private var saveAsProduct = false

    @State private var products: [Product] = []
    @State private var isLoadingProducts = true
    @State private var searchText = ""
    @State private var isSavingProduct = false
    @State private var errorMessage = ""

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
            $0.name.lowercased().contains(q) || $0.description.lowercased().contains(q)
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
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

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
            .task { await loadProducts() }
        }
    }

    // MARK: - Custom Item Form

    private var customItemForm: some View {
        ScrollView {
            VStack(spacing: 20) {
                FormSection(title: "Item Details") {
                    StyledFormField("Item Name", text: $name, placeholder: "e.g. Website Design, Logo Package")
                    StyledFormField("Description", text: $description, placeholder: "Optional details about this item")
                }

                FormSection(title: "Pricing") {
                    HStack(spacing: 12) {
                        StyledFormField("Quantity", text: $quantity, placeholder: "1", keyboard: .decimalPad)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Unit Price").font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Text(currencySymbol)
                                    .foregroundStyle(.secondary)
                                    .fontWeight(.medium)
                                TextField("0.00", text: $unitPrice)
                                    .keyboardType(.decimalPad)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 0.5))
                        }
                    }

                    // Amount preview
                    if amount > 0 {
                        HStack {
                            Text("Line Total").foregroundStyle(.secondary)
                            Spacer()
                            Text("\(currencySymbol)\(String(format: "%.2f", amount))")
                                .font(.title3.weight(.semibold))
                        }
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 0.5))
                    }
                }

                // Save toggle
                Toggle(isOn: $saveAsProduct) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Save for later")
                            .font(.subheadline)
                        Text("Add to your saved items for quick reuse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)

                if !errorMessage.isEmpty {
                    InlineBanner(message: errorMessage, style: .error)
                }

                ButtonPrimary(
                    title: saveAsProduct ? "Save & Add Item" : "Add Item",
                    isLoading: isSavingProduct,
                    isDisabled: !isValid
                ) {
                    addCustomItem()
                }
            }
            .padding(20)
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
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search saved items…", text: $searchText).autocorrectionDisabled()
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 20).padding(.top, 8)

                if isLoadingProducts {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filteredProducts) { product in
                                Button { selectProduct(product) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "cube.box")
                                            .font(.body).foregroundStyle(.blue)
                                            .frame(width: 36, height: 36)
                                            .background(Color.blue.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(product.name)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(.primary)
                                            if !product.description.isEmpty {
                                                Text(product.description)
                                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Text("\(currencySymbol)\(product.defaultPrice)")
                                            .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    }
                                    .padding(.vertical, 12).padding(.horizontal, 20)
                                }
                                .buttonStyle(.plain)
                                if product.id != filteredProducts.last?.id {
                                    Divider().padding(.leading, 68)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func addCustomItem() {
        if saveAsProduct {
            isSavingProduct = true
            Task {
                _ = try? await APIClient.shared.request(
                    Product.self, method: "POST", path: "/invoices/products/",
                    body: ["name": name, "description": description, "default_price": unitPrice]
                )
                await MainActor.run { isSavingProduct = false }
            }
        }
        onAdd(LocalItem(name: name, description: description, quantity: Double(quantity) ?? 1, unitPrice: Double(unitPrice) ?? 0))
        dismiss()
    }

    private func selectProduct(_ product: Product) {
        name = product.name
        description = product.description
        unitPrice = product.defaultPrice
        quantity = "1"
        activeTab = 0
    }

    private func loadProducts() async {
        do {
            let fetched = try await APIClient.shared.request([Product].self, method: "GET", path: "/invoices/products/")
            await MainActor.run { products = fetched; isLoadingProducts = false }
        } catch {
            await MainActor.run { isLoadingProducts = false }
        }
    }
}
