// Screens/InvoiceListScreen.swift
// Tab 2: All invoices with search + status filter.
// Tap any invoice → push to InvoiceDetailScreen.
import SwiftUI

struct InvoiceListScreen: View {
    @State private var invoices: [Invoice] = []
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var searchText = ""
    @State private var selectedFilter = "all"

    private let filters = ["all", "draft", "sent", "paid", "overdue"]

    private var filteredInvoices: [Invoice] {
        var result = invoices

        // Status filter
        if selectedFilter != "all" {
            result = result.filter { $0.status.lowercased() == selectedFilter }
        }

        // Search filter
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.clientName.lowercased().contains(q) ||
                $0.invoiceNumber.lowercased().contains(q) ||
                $0.total.contains(q)
            }
        }

        return result
    }

    // Group invoices by month
    private var groupedInvoices: [(String, [Invoice])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM yyyy"

        var groups: [String: [Invoice]] = [:]
        var order: [String] = []

        for invoice in filteredInvoices {
            let key: String
            if let date = formatter.date(from: invoice.issueDate) {
                key = displayFormatter.string(from: date)
            } else {
                key = "Other"
            }
            if groups[key] == nil {
                order.append(key)
            }
            groups[key, default: []].append(invoice)
        }

        return order.map { ($0, groups[$0]!) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search invoices...", text: $searchText)
                    .autocorrectionDisabled()
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Status filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.capitalized)
                                .font(.subheadline)
                                .fontWeight(selectedFilter == filter ? .semibold : .regular)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    selectedFilter == filter
                                        ? Color.blue.opacity(0.15)
                                        : Color(.systemGray6)
                                )
                                .foregroundStyle(
                                    selectedFilter == filter ? .blue : .primary
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider()

            // Invoice list
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredInvoices.isEmpty {
                EmptyState(
                    icon: "doc.text",
                    title: selectedFilter == "all" ? "No invoices yet" : "No \(selectedFilter) invoices",
                    message: selectedFilter == "all"
                        ? "Create your first invoice to get started."
                        : "No invoices with status \"\(selectedFilter)\" found."
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
        .task { loadInvoices() }
        .refreshable { loadInvoices() }
    }

    // MARK: - Load

    private func loadInvoices() {
        isLoading = invoices.isEmpty
        errorMessage = ""
        Task {
            do {
                let fetched = try await APIClient.shared.request(
                    [Invoice].self,
                    method: "GET",
                    path: "/invoices/"
                )
                await MainActor.run {
                    invoices = fetched
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
}
