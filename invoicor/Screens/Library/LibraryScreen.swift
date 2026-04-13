// Screens/LibraryScreen.swift
// Tab 4: Library — Clients + Saved Products in one place.
// Segmented picker at top to switch between the two.
// Both have search, add, and swipe-to-delete.

import SwiftUI

struct LibraryScreen: View {
    @State private var activeTab = 0  // 0 = Clients, 1 = Products
    @State private var clients: [Client] = []
    @State private var products: [Product] = []
    @State private var invoices: [Invoice] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showAddClient = false
    @State private var showAddProduct = false
    @State private var defaultCurrencySymbol = "$"
    @State private var businessProfiles: [BusinessProfile] = []

    var auth = AuthManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Segmented picker — 3 tabs
            Picker("", selection: $activeTab) {
                Text("Clients").tag(0)
                Text("Products").tag(1)
                Text("Business").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if activeTab == 2 {
                // Business profile tab — show profile cards, tap to edit
                businessTab
            } else {
                // Search bar (clients + products only)
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(activeTab == 0 ? "Search clients…" : "Search products…", text: $searchText)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16).padding(.vertical, 8)

                Divider()

            // Content
                // Content
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if activeTab == 0 {
                    clientsList
                } else {
                    productsList
                }
            } // end else (non-business tabs)
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if activeTab != 2 {
                    Button {
                        if activeTab == 0 { showAddClient = true }
                        else { showAddProduct = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task { await loadData() }
        .refreshable { await loadData() }
        .sheet(isPresented: $showAddClient, onDismiss: { Task { await refreshClients() } }) {
            ClientFormSheet(clients: $clients, editing: nil)
        }
        .sheet(isPresented: $showAddProduct, onDismiss: { Task { await refreshProducts() } }) {
            ProductFormSheet(products: $products, editing: nil, currencySymbol: defaultCurrencySymbol)
        }
        .onChange(of: activeTab) { _, _ in searchText = "" }
    }

    // MARK: - Business Tab

    private var businessTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if businessProfiles.isEmpty {
                    emptyState(
                        icon: "building.2",
                        title: "No business profile",
                        message: "Set up your business info to start creating invoices.",
                        buttonTitle: "Set Up Profile"
                    ) {
                        // Navigate to BusinessProfileScreen
                    }
                } else {
                    ForEach(businessProfiles) { profile in
                        NavigationLink {
                            BusinessProfileScreen()
                        } label: {
                            HStack(spacing: 14) {
                                // Avatar
                                ZStack {
                                    Circle().fill(avatarColor(for: profile.companyName.isEmpty ? "BP" : profile.companyName))
                                    Text(avatarInitials(profile.companyName.isEmpty ? "BP" : profile.companyName))
                                        .font(.caption.weight(.bold)).foregroundStyle(.white)
                                }
                                .frame(width: 44, height: 44)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(profile.displayName)
                                            .font(.body.weight(.medium)).foregroundStyle(.primary)
                                        if profile.isDefault {
                                            Text("Default")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.blue)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1))
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }
                                    }
                                    if !profile.email.isEmpty {
                                        Text(profile.email)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    if !profile.formattedAddress.isEmpty {
                                        Text(profile.formattedAddress)
                                            .font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .background(Color(.systemGray6).opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Clients List

    private var filteredClients: [Client] {
        if searchText.isEmpty { return clients }
        let q = searchText.lowercased()
        return clients.filter {
            $0.companyName.lowercased().contains(q) ||
            $0.contactName.lowercased().contains(q) ||
            $0.email.lowercased().contains(q) ||
            $0.phone.lowercased().contains(q) ||
            $0.city.lowercased().contains(q) ||
            $0.country.lowercased().contains(q)
        }
    }

    private var clientsList: some View {
        Group {
            if filteredClients.isEmpty {
                emptyState(
                    icon: "person.2",
                    title: searchText.isEmpty ? "No clients yet" : "No results",
                    message: searchText.isEmpty ? "Add your first client to start invoicing." : "Try a different search term.",
                    buttonTitle: searchText.isEmpty ? "Add Client" : nil
                ) { showAddClient = true }
            } else {
                List {
                    ForEach(filteredClients) { client in
                        NavigationLink {
                            ClientDetailScreen(clientId: client.publicId, allInvoices: invoices)
                        } label: {
                            clientRow(client)
                        }
                    }
                    .onDelete { indexSet in
                        deleteClients(at: indexSet)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func clientRow(_ client: Client) -> some View {
        let stats = clientStats(for: client)
        return HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle().fill(avatarColor(for: client.displayName))
                Text(avatarInitials(client.displayName))
                    .font(.caption.weight(.bold)).foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(client.displayName)
                    .font(.body.weight(.medium)).lineLimit(1)
                HStack(spacing: 6) {
                    if stats.invoiceCount > 0 {
                        Text("\(stats.invoiceCount) inv.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !client.email.isEmpty {
                        Text(client.email)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }

            Spacer()

            if stats.totalPaid > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(defaultCurrencySymbol)\(String(format: "%.0f", stats.totalPaid))")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.green)
                    Text("lifetime").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Products List

    private var filteredProducts: [Product] {
        if searchText.isEmpty { return products }
        let q = searchText.lowercased()
        return products.filter {
            $0.name.lowercased().contains(q) ||
            $0.description.lowercased().contains(q)
        }
    }

    @State private var editingProduct: Product? = nil

    private var productsList: some View {
        Group {
            if filteredProducts.isEmpty {
                emptyState(
                    icon: "archivebox",
                    title: searchText.isEmpty ? "No saved products" : "No results",
                    message: searchText.isEmpty ? "Save your services and products for faster invoicing." : "Try a different search term.",
                    buttonTitle: searchText.isEmpty ? "Add Product" : nil
                ) { showAddProduct = true }
            } else {
                List {
                    ForEach(filteredProducts) { product in
                        Button { editingProduct = product } label: {
                            productRow(product)
                        }
                    }
                    .onDelete { indexSet in
                        deleteProducts(at: indexSet)
                    }
                }
                .listStyle(.plain)
                .sheet(item: $editingProduct, onDismiss: { Task { await refreshProducts() } }) { product in
                    ProductFormSheet(products: $products, editing: product, currencySymbol: defaultCurrencySymbol)
                }
            }
        }
    }

    private func productRow(_ product: Product) -> some View {
        HStack(spacing: 12) {
            // Colored initial avatar (like clients)
            ZStack {
                Circle().fill(avatarColor(for: product.name))
                Text(avatarInitials(product.name))
                    .font(.caption.weight(.bold)).foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.body.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                if !product.description.isEmpty {
                    Text(product.description)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Spacer()

            Text("\(defaultCurrencySymbol)\(product.defaultPrice)")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, message: String, buttonTitle: String? = nil, action: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            if let buttonTitle {
                Button { action() } label: {
                    Text(buttonTitle).font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent).padding(.top, 4)
            }
            Spacer()
        }
    }

    // MARK: - Client Stats

    private func clientStats(for client: Client) -> (invoiceCount: Int, totalPaid: Double) {
        let matched = invoices.filter { inv in
            (inv.clientSnapshot["company_name"]?.stringValue == client.companyName && !client.companyName.isEmpty) ||
            (inv.clientSnapshot["contact_name"]?.stringValue == client.contactName && !client.contactName.isEmpty)
        }
        let paid = matched.filter { $0.status == "paid" }.compactMap { Double($0.total) }.reduce(0, +)
        return (matched.count, paid)
    }

    // MARK: - Avatar Helpers

    private func avatarInitials(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 { return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo]
        return colors[abs(name.hashValue) % colors.count]
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = clients.isEmpty && products.isEmpty
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await refreshClients() }
            group.addTask { await refreshProducts() }
            group.addTask { await refreshInvoices() }
            group.addTask { await refreshBusinessProfiles() }
            group.addTask { await loadCurrencySymbol() }
        }
        await MainActor.run { isLoading = false }
    }

    private func refreshClients() async {
        if let fetched = try? await APIClient.shared.request([Client].self, method: "GET", path: "/accounts/clients/") {
            await MainActor.run { clients = fetched }
        }
    }

    private func refreshProducts() async {
        if let fetched = try? await APIClient.shared.request([Product].self, method: "GET", path: "/invoices/products/") {
            await MainActor.run { products = fetched }
        }
    }

    private func refreshInvoices() async {
        if let response = try? await APIClient.shared.request(InvoiceListResponse.self, method: "GET", path: "/invoices/") {
            await MainActor.run { invoices = response.results }
        }
    }

    private func refreshBusinessProfiles() async {
        if let fetched = try? await APIClient.shared.request([BusinessProfile].self, method: "GET", path: "/accounts/business-profiles/") {
            await MainActor.run { businessProfiles = fetched }
        }
    }

    private func loadCurrencySymbol() async {
        if let profiles = try? await APIClient.shared.request([BusinessProfile].self, method: "GET", path: "/accounts/business-profiles/"),
           let bp = profiles.first,
           let currencies = try? await APIClient.shared.request([Currency].self, method: "GET", path: "/invoices/currencies/"),
           let match = currencies.first(where: { $0.code == bp.defaultCurrency }) {
            await MainActor.run { defaultCurrencySymbol = match.symbol }
        }
    }

    // MARK: - Delete

    private func deleteClients(at offsets: IndexSet) {
        let toDelete = offsets.map { filteredClients[$0] }
        for client in toDelete {
            Task {
                try? await APIClient.shared.requestNoContent(method: "DELETE", path: "/accounts/clients/\(client.publicId)/")
                await MainActor.run { clients.removeAll { $0.publicId == client.publicId } }
            }
        }
    }

    private func deleteProducts(at offsets: IndexSet) {
        let toDelete = offsets.map { filteredProducts[$0] }
        for product in toDelete {
            Task {
                try? await APIClient.shared.requestNoContent(method: "DELETE", path: "/invoices/products/\(product.publicId)/")
                await MainActor.run { products.removeAll { $0.publicId == product.publicId } }
            }
        }
    }
}
