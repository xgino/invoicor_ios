// Screens/InvoiceListScreen.swift
// Tab 2: All invoices with search, status filter, business filter, client filter, and sort.
// Accepts optional initialFilter to pre-select a status (e.g. from dashboard alerts).

import SwiftUI

struct InvoiceListScreen: View {
    var initialFilter: String? = nil

    @State private var invoices: [Invoice] = []
    @State private var profiles: [BusinessProfile] = []
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var searchText = ""
    @State private var selectedStatus = "all"
    @State private var selectedProfileId: String? = nil // nil = all businesses
    @State private var selectedClientName: String? = nil // nil = all clients
    @State private var sortBy: SortOption = .newest
    @State private var showFilters = false

    private let statusFilters = ["all", "draft", "sent", "paid", "overdue", "cancelled"]

    private enum SortOption: String, CaseIterable {
        case newest = "Newest"
        case oldest = "Oldest"
        case highestAmount = "Highest"
        case lowestAmount = "Lowest"
    }

    // MARK: - Derived Data

    /// Unique client names from all invoices
    private var clientNames: [String] {
        let names = Set(invoices.map { $0.clientName }.filter { !$0.isEmpty })
        return names.sorted()
    }

    /// Active filter count (for badge on filter button)
    private var activeFilterCount: Int {
        var count = 0
        if selectedProfileId != nil { count += 1 }
        if selectedClientName != nil { count += 1 }
        if sortBy != .newest { count += 1 }
        return count
    }

    // MARK: - Filtered + Sorted Invoices

    private var filteredInvoices: [Invoice] {
        var result = invoices

        // Status filter
        if selectedStatus != "all" {
            result = result.filter { $0.status.lowercased() == selectedStatus }
        }

        // Business profile filter (match sender company name)
        if let profileId = selectedProfileId,
           let profile = profiles.first(where: { $0.publicId == profileId }) {
            let name = profile.companyName.lowercased()
            if !name.isEmpty {
                result = result.filter {
                    ($0.senderSnapshot["company_name"]?.stringValue ?? "").lowercased() == name
                }
            }
        }

        // Client filter
        if let clientName = selectedClientName {
            result = result.filter { $0.clientName == clientName }
        }

        // Search
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.clientName.lowercased().contains(q) ||
                $0.invoiceNumber.lowercased().contains(q) ||
                $0.total.contains(q) ||
                $0.currency.lowercased().contains(q) ||
                $0.status.lowercased().contains(q)
            }
        }

        // Sort
        switch sortBy {
        case .newest:
            result.sort { $0.issueDate > $1.issueDate }
        case .oldest:
            result.sort { $0.issueDate < $1.issueDate }
        case .highestAmount:
            result.sort { (Double($0.total) ?? 0) > (Double($1.total) ?? 0) }
        case .lowestAmount:
            result.sort { (Double($0.total) ?? 0) < (Double($1.total) ?? 0) }
        }

        return result
    }

    private var groupedInvoices: [(String, [Invoice])] {
        let parser = DateFormatter(); parser.dateFormat = "yyyy-MM-dd"
        let display = DateFormatter(); display.dateFormat = "MMMM yyyy"
        var groups: [String: [Invoice]] = [:]
        var order: [String] = []
        for invoice in filteredInvoices {
            let key = parser.date(from: invoice.issueDate).map { display.string(from: $0) } ?? "Other"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(invoice)
        }
        return order.map { ($0, groups[$0]!) }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search + filter button
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search invoices…", text: $searchText).autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Filter button with badge
                Button { showFilters.toggle() } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundStyle(activeFilterCount > 0 || showFilters ? .blue : .secondary)
                        if activeFilterCount > 0 {
                            Text("\(activeFilterCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 14, height: 14)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8)

            // Status filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(statusFilters, id: \.self) { filter in
                        statusPill(filter)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }

            // Expandable filter panel
            if showFilters {
                filterPanel
            }

            Divider()

            // Results count
            if !isLoading {
                HStack {
                    Text("\(filteredInvoices.count) invoice\(filteredInvoices.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.tertiary)
                    Spacer()
                    if activeFilterCount > 0 {
                        Button {
                            withAnimation {
                                selectedProfileId = nil
                                selectedClientName = nil
                                sortBy = .newest
                            }
                        } label: {
                            Text("Clear filters").font(.caption).foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
            }

            // List
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredInvoices.isEmpty {
                EmptyState(
                    icon: "doc.text",
                    title: selectedStatus == "all" ? "No invoices yet" : "No \(selectedStatus) invoices",
                    message: selectedStatus == "all"
                        ? "Create your first invoice to get started."
                        : "No invoices match your filters."
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(groupedInvoices, id: \.0) { month, invoicesInMonth in
                        Section(month.uppercased()) {
                            ForEach(invoicesInMonth) { invoice in
                                NavigationLink {
                                    InvoiceDetailScreen(invoiceId: invoice.publicId)
                                } label: {
                                    InvoiceRow(invoice: invoice)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Invoices")
        .task {
            if let filter = initialFilter, statusFilters.contains(filter) {
                selectedStatus = filter
            }
            await loadData()
        }
        .refreshable { await loadData() }
    }

    // MARK: - Filter Panel

    private var filterPanel: some View {
        VStack(spacing: 12) {
            // Business profile filter
            if profiles.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Business").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            filterChip(label: "All", isActive: selectedProfileId == nil) {
                                selectedProfileId = nil
                            }
                            ForEach(profiles, id: \.publicId) { profile in
                                filterChip(
                                    label: profile.companyName.isEmpty ? "Unnamed" : profile.companyName,
                                    isActive: selectedProfileId == profile.publicId
                                ) {
                                    selectedProfileId = profile.publicId
                                }
                            }
                        }
                    }
                }
            }

            // Client filter
            if !clientNames.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Client").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            filterChip(label: "All", isActive: selectedClientName == nil) {
                                selectedClientName = nil
                            }
                            ForEach(clientNames, id: \.self) { name in
                                filterChip(label: name, isActive: selectedClientName == name) {
                                    selectedClientName = name
                                }
                            }
                        }
                    }
                }
            }

            // Sort
            VStack(alignment: .leading, spacing: 6) {
                Text("Sort by").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        filterChip(label: option.rawValue, isActive: sortBy == option) {
                            sortBy = option
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(.systemGray6).opacity(0.5))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func statusPill(_ filter: String) -> some View {
        let isActive = selectedStatus == filter
        let count = countForStatus(filter)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedStatus = filter }
        } label: {
            HStack(spacing: 4) {
                Text(filter.capitalized)
                if count > 0 && filter != "all" {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(isActive ? .blue : Color(.tertiaryLabel))
                }
            }
            .font(.subheadline.weight(isActive ? .semibold : .regular))
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(isActive ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .foregroundStyle(isActive ? .blue : .primary)
            .clipShape(Capsule())
        }
    }

    private func countForStatus(_ filter: String) -> Int {
        if filter == "all" { return invoices.count }
        return invoices.filter { $0.status.lowercased() == filter }.count
    }

    private func filterChip(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { action() }
        } label: {
            Text(label)
                .font(.caption.weight(isActive ? .semibold : .regular))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(isActive ? Color.blue.opacity(0.12) : Color(.systemGray6))
                .foregroundStyle(isActive ? .blue : .primary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isActive ? Color.blue.opacity(0.3) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Load

    private func loadData() async {
        isLoading = invoices.isEmpty
        do {
            let response = try await APIClient.shared.request(
                InvoiceListResponse.self, method: "GET", path: "/invoices/")
            let prof = try await APIClient.shared.request(
                [BusinessProfile].self, method: "GET", path: "/accounts/business-profiles/")
            await MainActor.run {
                invoices = response.results
                profiles = prof
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Failed to load"
                isLoading = false
            }
        }
    }
}cla
