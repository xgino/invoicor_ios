// Screens/Home/HomeScreen.swift
// Dashboard — refreshes every time the tab appears (not just first load).
// Shows combined stats across all profiles for single-profile users.
// Profile switcher only visible for multi-profile (Pro+) users.

import SwiftUI
import Charts

struct HomeScreen: View {
    var auth = AuthManager.shared
    @State private var invoices: [Invoice] = []
    @State private var profiles: [BusinessProfile] = []
    @State private var selectedProfile: BusinessProfile? = nil
    @State private var isLoading = true
    @State private var hasLoadedOnce = false

    // MARK: - Currency

    private var currencySymbol: String {
        let code = selectedProfile?.defaultCurrency ?? "USD"
        let symbols: [String: String] = [
            "USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥", "CHF": "CHF",
            "CAD": "CA$", "AUD": "A$", "INR": "₹", "BRL": "R$", "SEK": "kr",
            "NOK": "kr", "DKK": "kr", "PLN": "zł", "TRY": "₺", "ZAR": "R",
            "KRW": "₩", "SGD": "S$", "HKD": "HK$", "NZD": "NZ$", "ILS": "₪",
        ]
        return symbols[code] ?? code
    }

    // Show all invoices if single profile, filter by currency if multi
    private var displayInvoices: [Invoice] {
        if profiles.count <= 1 { return invoices }
        guard let profile = selectedProfile else { return invoices }
        return invoices.filter { $0.currency == profile.defaultCurrency }
    }

    // MARK: - Stats

    private var paidThisMonth: Double {
        let cal = Calendar.current; let now = Date()
        return displayInvoices
            .filter { $0.status == "paid" }
            .filter { parseDate($0.issueDate).map { cal.isDate($0, equalTo: now, toGranularity: .month) } ?? false }
            .compactMap { Double($0.total) }.reduce(0, +)
    }

    private var paidLastMonth: Double {
        let cal = Calendar.current; let now = Date()
        guard let lastMonth = cal.date(byAdding: .month, value: -1, to: now) else { return 0 }
        return displayInvoices
            .filter { $0.status == "paid" }
            .filter { parseDate($0.issueDate).map { cal.isDate($0, equalTo: lastMonth, toGranularity: .month) } ?? false }
            .compactMap { Double($0.total) }.reduce(0, +)
    }

    private var outstanding: Double {
        displayInvoices
            .filter { $0.status == "sent" || $0.status == "overdue" }
            .compactMap { Double($0.total) }.reduce(0, +)
    }

    private var overdueInvoices: [Invoice] { displayInvoices.filter { $0.status == "overdue" } }
    private var draftInvoices: [Invoice] { displayInvoices.filter { $0.status == "draft" } }
    private var sentInvoices: [Invoice] { displayInvoices.filter { $0.status == "sent" } }

    // MARK: - Chart Data

    private var revenueByMonth: [MonthRevenue] {
        let cal = Calendar.current; let now = Date()
        return (0..<6).reversed().compactMap { i -> MonthRevenue? in
            guard let monthDate = cal.date(byAdding: .month, value: -i, to: now) else { return nil }
            let m = cal.component(.month, from: monthDate); let y = cal.component(.year, from: monthDate)
            let total = displayInvoices
                .filter { $0.status == "paid" }
                .filter { guard let d = parseDate($0.issueDate) else { return false }
                    return cal.component(.month, from: d) == m && cal.component(.year, from: d) == y }
                .compactMap { Double($0.total) }.reduce(0, +)
            let df = DateFormatter(); df.dateFormat = "MMM"
            return MonthRevenue(month: df.string(from: monthDate), amount: total)
        }
    }

    // Revenue trend (compared to last month)
    private var revenueTrend: (text: String, color: Color)? {
        guard paidLastMonth > 0 else { return nil }
        let change = ((paidThisMonth - paidLastMonth) / paidLastMonth) * 100
        if change > 0 {
            return ("+\(String(format: "%.0f", change))% vs last month", .green)
        } else if change < 0 {
            return ("\(String(format: "%.0f", change))% vs last month", .red)
        }
        return ("Same as last month", .secondary)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                statsRow
                revenueCard
                alertsSection
                recentSection
            }
            .padding(.horizontal, hp)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle(navTitle)
        .onAppear { Task { await loadData() } }  // Refresh EVERY time tab appears
        .refreshable { await loadData() }
    }

    private var navTitle: String {
        if profiles.count > 1, let p = selectedProfile, !p.companyName.isEmpty {
            return p.companyName
        }
        return "Dashboard"
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText).font(.subheadline).foregroundStyle(.secondary)
                if let usage = auth.usage {
                    Text(usageLabel(usage)).font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            // Only show profile switcher for multi-profile users
            if profiles.count > 1 {
                profilePicker
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    private func usageLabel(_ usage: UsageInfo) -> String {
        if let l = usage.invoicesLifetimeLimit { return "\(usage.invoicesTotal)/\(l) free invoices" }
        if let m = usage.invoicesMonthlyLimit { return "\(usage.invoicesThisMonth)/\(m) this month" }
        return "\(usage.invoicesThisMonth) invoices this month"
    }

    private var profilePicker: some View {
        Menu {
            ForEach(profiles, id: \.publicId) { profile in
                Button {
                    selectedProfile = profile
                } label: {
                    HStack {
                        Text(profile.companyName.isEmpty ? "Unnamed" : profile.companyName)
                        if profile.publicId == selectedProfile?.publicId { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "building.2").font(.caption)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .foregroundStyle(.secondary).padding(8)
            .background(Color(.systemGray6)).clipShape(Circle())
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(title: "Paid this month", value: "\(currencySymbol)\(fmtC(paidThisMonth))", color: .green)
            statCard(title: "Outstanding", value: outstanding > 0 ? "\(currencySymbol)\(fmtC(outstanding))" : "—",
                     color: outstanding > 0 ? .orange : .secondary)
            if let usage = auth.usage {
                statCard(title: auth.currentUser?.tier == "free" ? "Free invoices" : "This month",
                         value: usageValue(usage), color: .blue)
            }
        }
    }

    private func usageValue(_ usage: UsageInfo) -> String {
        if let l = usage.invoicesLifetimeLimit { return "\(usage.invoicesTotal)/\(l)" }
        if let m = usage.invoicesMonthlyLimit { return "\(usage.invoicesThisMonth)/\(m)" }
        return "\(displayInvoices.count)"
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Revenue Chart

    private var revenueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("REVENUE").font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(0.5)
                Spacer()
                if let trend = revenueTrend {
                    Text(trend.text).font(.caption2).foregroundStyle(trend.color)
                }
            }

            if revenueByMonth.allSatisfy({ $0.amount == 0 }) {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar").font(.title2).foregroundStyle(.tertiary)
                    Text("Revenue chart appears when invoices are paid").font(.caption).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                Chart(revenueByMonth) { item in
                    BarMark(x: .value("Month", item.month), y: .value("Revenue", item.amount))
                        .foregroundStyle(LinearGradient(colors: [.blue, .blue.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(4)
                }
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let amt = value.as(Double.self) { Text("\(currencySymbol)\(fmtC(amt))").font(.caption2) }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func quickAction(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { quickActionLabel(icon: icon, title: title, color: color) }
    }

    private func quickActionLabel(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(title).font(.caption2.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.systemGray6).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        VStack(spacing: 8) {
            if !overdueInvoices.isEmpty {
                NavigationLink {
                    InvoiceDetailScreen(invoiceId: overdueInvoices.first!.publicId)
                } label: {
                    alertRow(icon: "exclamationmark.triangle.fill", color: .red,
                             text: "\(overdueInvoices.count) overdue",
                             detail: "\(currencySymbol)\(fmtC(overdueInvoices.compactMap { Double($0.total) }.reduce(0, +))) unpaid")
                }
            }
            if !draftInvoices.isEmpty {
                alertRow(icon: "pencil.circle.fill", color: .secondary,
                         text: "\(draftInvoices.count) draft\(draftInvoices.count == 1 ? "" : "s") waiting to send", detail: nil)
            }
            if outstanding > 0 && overdueInvoices.isEmpty {
                alertRow(icon: "clock.fill", color: .orange,
                         text: "\(currencySymbol)\(fmtC(outstanding)) awaiting payment", detail: nil)
            }
        }
    }

    private func alertRow(icon: String, color: Color, text: String, detail: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(text).font(.subheadline)
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Recent Invoices

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT").font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(0.5)

            if displayInvoices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text").font(.title2).foregroundStyle(.tertiary)
                    Text("No invoices yet").font(.caption).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(displayInvoices.prefix(5)) { invoice in
                        NavigationLink {
                            InvoiceDetailScreen(invoiceId: invoice.publicId)
                        } label: {
                            InvoiceRow(invoice: invoice)
                        }
                        .foregroundStyle(.primary).padding(.vertical, 8)
                        if invoice.id != displayInvoices.prefix(5).last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Color(.systemGray6).opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Helpers

    private func fmtC(_ value: Double) -> String {
        if value >= 10000 { return String(format: "%.0fk", value / 1000) }
        if value >= 1000 { return String(format: "%.1fk", value / 1000) }
        return String(format: "%.0f", value)
    }

    private func parseDate(_ str: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: str)
    }

    private var hp: CGFloat {
        let w = UIScreen.main.bounds.width; if w > 430 { return 24 }; if w > 390 { return 20 }; return 16
    }

    // MARK: - Load Data

    private func loadData() async {
        if !hasLoadedOnce { isLoading = true }
        do {
            async let invReq = APIClient.shared.request(InvoiceListResponse.self, method: "GET", path: "/invoices/")
            async let profReq = APIClient.shared.request([BusinessProfile].self, method: "GET", path: "/accounts/business-profiles/")
            let (inv, prof) = try await (invReq, profReq)
            await MainActor.run {
                invoices = inv.results; profiles = prof
                if selectedProfile == nil { selectedProfile = prof.first(where: { $0.isDefault }) ?? prof.first }
                isLoading = false; hasLoadedOnce = true
            }
            await auth.refreshMe()
        } catch {
            await MainActor.run { isLoading = false; hasLoadedOnce = true }
        }
    }
}

struct MonthRevenue: Identifiable {
    let id = UUID()
    let month: String
    let amount: Double
}
