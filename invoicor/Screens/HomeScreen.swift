// Screens/HomeScreen.swift
// Dashboard: revenue chart + actionable alerts + quick stats.
// Uses the user's default currency from their business profile.
// Multi-business switcher for Pro/Business tier.
import SwiftUI
import Charts
import RevenueCat
import RevenueCatUI

struct HomeScreen: View {
    var auth = AuthManager.shared
    @State private var invoices: [Invoice] = []
    @State private var profiles: [BusinessProfile] = []
    @State private var selectedProfile: BusinessProfile? = nil
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showProfilePicker = false

    // Derived currency from selected business profile
    private var currencySymbol: String {
        let code = selectedProfile?.defaultCurrency ?? "USD"
        // Common symbols
        let symbols: [String: String] = [
            "USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥",
            "CHF": "CHF", "CAD": "CA$", "AUD": "A$", "CNY": "¥",
            "INR": "₹", "BRL": "R$", "SEK": "kr", "NOK": "kr",
            "DKK": "kr", "PLN": "zł", "TRY": "₺", "ZAR": "R",
            "KRW": "₩", "SGD": "S$", "HKD": "HK$", "NZD": "NZ$",
            "AED": "د.إ", "THB": "฿", "MYR": "RM", "PHP": "₱",
            "ILS": "₪",
        ]
        return symbols[code] ?? code
    }

    // Filter invoices to selected profile's currency
    private var profileInvoices: [Invoice] {
        guard let profile = selectedProfile else { return invoices }
        return invoices.filter { $0.currency == profile.defaultCurrency }
    }

    // MARK: - Stats

    private var paidThisMonth: Double {
        let cal = Calendar.current
        let now = Date()
        return profileInvoices
            .filter { $0.status == "paid" }
            .filter { dateFromString($0.issueDate).map { cal.isDate($0, equalTo: now, toGranularity: .month) } ?? false }
            .compactMap { Double($0.total) }
            .reduce(0, +)
    }

    private var outstanding: Double {
        profileInvoices
            .filter { $0.status == "sent" || $0.status == "overdue" }
            .compactMap { Double($0.total) }
            .reduce(0, +)
    }

    private var overdueInvoices: [Invoice] {
        profileInvoices.filter { $0.status == "overdue" }
    }

    private var draftCount: Int {
        profileInvoices.filter { $0.status == "draft" }.count
    }

    // MARK: - Chart Data (last 6 months)

    private var revenueByMonth: [MonthRevenue] {
        let cal = Calendar.current
        let now = Date()
        var result: [MonthRevenue] = []

        for i in (0..<6).reversed() {
            guard let monthDate = cal.date(byAdding: .month, value: -i, to: now) else { continue }
            let month = cal.component(.month, from: monthDate)
            let year = cal.component(.year, from: monthDate)

            let total = profileInvoices
                .filter { $0.status == "paid" }
                .filter {
                    guard let d = dateFromString($0.issueDate) else { return false }
                    return cal.component(.month, from: d) == month &&
                           cal.component(.year, from: d) == year
                }
                .compactMap { Double($0.total) }
                .reduce(0, +)

            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let label = formatter.string(from: monthDate)

            result.append(MonthRevenue(month: label, amount: total))
        }
        return result
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Business profile switcher (if multiple profiles)
                if profiles.count > 1 {
                    profileSwitcher
                }

                // Stats cards
                statsCards

                // Revenue chart
                revenueChart

                // Alerts
                alertsSection

                // Recent invoices
                recentSection
            }
            .padding(16)
        }
        .navigationTitle(selectedProfile?.companyName ?? "Dashboard")
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    // MARK: - Profile Switcher

    private var profileSwitcher: some View {
        Menu {
            ForEach(profiles, id: \.publicId) { profile in
                Button {
                    selectedProfile = profile
                } label: {
                    HStack {
                        Text(profile.companyName.isEmpty ? "Unnamed" : profile.companyName)
                        if profile.publicId == selectedProfile?.publicId {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedProfile?.companyName ?? "Select Business")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Paid this month",
                value: "\(currencySymbol)\(formatAmount(paidThisMonth))",
                color: .green
            )
            StatCard(
                title: "Outstanding",
                value: outstanding > 0 ? "\(currencySymbol)\(formatAmount(outstanding))" : "—",
                color: outstanding > 0 ? .orange : .secondary
            )
            if let usage = auth.usage {
                StatCard(
                    title: "Invoices",
                    value: usage.invoicesLimit != nil
                        ? "\(usage.invoicesUsed)/\(usage.invoicesLimit!)"
                        : "\(usage.invoicesUsed)",
                    color: .blue
                )
            }
        }
    }

    // MARK: - Revenue Chart

    private var revenueChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Revenue")
                .font(.headline)

            if revenueByMonth.allSatisfy({ $0.amount == 0 }) {
                // Empty chart state
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No paid invoices yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Your revenue chart will appear here once invoices are marked as paid.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                Chart(revenueByMonth) { item in
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Revenue", item.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text("\(currencySymbol)\(formatCompact(amount))")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Alerts Section

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !overdueInvoices.isEmpty {
                alertCard(
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    text: "\(overdueInvoices.count) invoice\(overdueInvoices.count == 1 ? "" : "s") overdue",
                    detail: "\(currencySymbol)\(formatAmount(overdueInvoices.compactMap { Double($0.total) }.reduce(0, +))) unpaid"
                )
            }

            if paidThisMonth > 0 {
                alertCard(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    text: "\(currencySymbol)\(formatAmount(paidThisMonth)) paid this month",
                    detail: nil
                )
            }

            if draftCount > 0 {
                alertCard(
                    icon: "pencil.circle.fill",
                    color: .secondary,
                    text: "\(draftCount) draft\(draftCount == 1 ? "" : "s") waiting to send",
                    detail: nil
                )
            }

            if outstanding > 0 && overdueInvoices.isEmpty {
                alertCard(
                    icon: "clock.fill",
                    color: .orange,
                    text: "\(currencySymbol)\(formatAmount(outstanding)) awaiting payment",
                    detail: nil
                )
            }

            // Nothing happening
            if overdueInvoices.isEmpty && paidThisMonth == 0 && draftCount == 0 && outstanding == 0 {
                EmptyState(
                    icon: "doc.text",
                    title: "No activity yet",
                    message: "Create your first invoice to see your dashboard come alive."
                )
            }
        }
    }

    private func alertCard(icon: String, color: Color, text: String, detail: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Recent Invoices

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent")
                    .font(.headline)
                Spacer()
                // "See All" could switch to Invoices tab
                Text("See All")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }

            if profileInvoices.isEmpty {
                Text("No invoices yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(profileInvoices.prefix(5)) { invoice in
                    NavigationLink {
                        InvoiceDetailScreen(invoiceId: invoice.publicId)
                    } label: {
                        InvoiceRow(invoice: invoice)
                    }
                    .foregroundStyle(.primary)
                    if invoice.id != profileInvoices.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Formatting

    private func formatAmount(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    private func formatCompact(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }

    private func dateFromString(_ str: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: str)
    }

    // MARK: - Load Data

    private func loadData() async {
        isLoading = invoices.isEmpty
        errorMessage = ""
        do {
            async let invReq = APIClient.shared.request(
                [Invoice].self, method: "GET", path: "/invoices/"
            )
            async let profReq = APIClient.shared.request(
                [BusinessProfile].self, method: "GET", path: "/accounts/business-profiles/"
            )

            let (fetchedInv, fetchedProf) = try await (invReq, profReq)

            await MainActor.run {
                invoices = fetchedInv
                profiles = fetchedProf
                // Select default profile
                if selectedProfile == nil {
                    selectedProfile = fetchedProf.first(where: { $0.isDefault }) ?? fetchedProf.first
                }
                isLoading = false
            }

            await auth.refreshMe()
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Failed to load"
                isLoading = false
            }
        }
    }
}

// MARK: - Chart Data Model

struct MonthRevenue: Identifiable {
    let id = UUID()
    let month: String
    let amount: Double
}
