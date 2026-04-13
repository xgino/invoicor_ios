// Screens/InvoiceListScreen.swift
// Tab 2: All invoices with search + status filter.
// Uses InvoiceListResponse (paginated) from API.

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
        if selectedFilter != "all" {
            result = result.filter { $0.status.lowercased() == selectedFilter }
        }
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

    private var groupedInvoices: [(String, [Invoice])] {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        let display = DateFormatter()
        display.dateFormat = "MMMM yyyy"

        var groups: [String: [Invoice]] = [:]
        var order: [String] = []

        for invoice in filteredInvoices {
            let key = parser.date(from: invoice.issueDate).map { display.string(from: $0) } ?? "Other"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(invoice)
        }
        return order.map { ($0, groups[$0]!) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search invoices…", text: $searchText).autocorrectionDisabled()
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16).padding(.top, 8)

            // Status filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.capitalized)
                                .font(.subheadline.weight(selectedFilter == filter ? .semibold : .regular))
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(selectedFilter == filter ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                .foregroundStyle(selectedFilter == filter ? .blue : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }

            Divider()

            // List
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .task { await loadInvoices() }
        .refreshable { await loadInvoices() }
    }

    // MARK: - Load (paginated response)

    private func loadInvoices() async {
        isLoading = invoices.isEmpty
        do {
            let response = try await APIClient.shared.request(
                InvoiceListResponse.self, method: "GET", path: "/invoices/"
            )
            await MainActor.run {
                invoices = response.results
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
