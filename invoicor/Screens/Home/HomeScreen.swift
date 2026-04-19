// Screens/Home/HomeScreen.swift
// Dashboard -- global time range + business profile filter.
// Compare toggle shows previous period side-by-side.
// Calendar-aligned: week=Mon, month=1st, quarter=Q start, year=Jan 1.

import SwiftUI
import Charts

struct HomeScreen: View {
    var auth = AuthManager.shared
    @State private var invoices: [Invoice] = []
    @State private var profiles: [BusinessProfile] = []
    @State private var selectedProfileId: String? = nil
    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    @State private var timeRange: TimeRange = .week
    @State private var showCompare = false

    private enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
        case all = "All"
    }

    // MARK: - Calendar-Aligned Dates

    private var weekStart: Date {
        let cal = Calendar(identifier: .iso8601)
        return cal.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date ?? Date()
    }

    private var monthStart: Date {
        let cal = Calendar.current
        return cal.dateComponents([.calendar, .year, .month], from: Date()).date ?? Date()
    }

    private var quarterStart: Date {
        let cal = Calendar.current
        let month = cal.component(.month, from: Date())
        let qMonth = ((month - 1) / 3) * 3 + 1
        var comps = cal.dateComponents([.year], from: Date())
        comps.month = qMonth; comps.day = 1
        return cal.date(from: comps) ?? Date()
    }

    private var yearStart: Date {
        let cal = Calendar.current
        return cal.dateComponents([.calendar, .year], from: Date()).date ?? Date()
    }

    private var filterCutoff: Date? {
        switch timeRange {
        case .week:    return weekStart
        case .month:   return monthStart
        case .quarter: return quarterStart
        case .year:    return yearStart
        case .all:     return nil
        }
    }

    /// Previous period cutoff for compare mode
    private var previousPeriodRange: (start: Date, end: Date)? {
        let cal = Calendar.current
        switch timeRange {
        case .week:
            guard let prevStart = cal.date(byAdding: .weekOfYear, value: -1, to: weekStart) else { return nil }
            return (prevStart, weekStart)
        case .month:
            guard let prevStart = cal.date(byAdding: .month, value: -1, to: monthStart) else { return nil }
            return (prevStart, monthStart)
        case .quarter:
            guard let prevStart = cal.date(byAdding: .month, value: -3, to: quarterStart) else { return nil }
            return (prevStart, quarterStart)
        case .year:
            guard let prevStart = cal.date(byAdding: .year, value: -1, to: yearStart) else { return nil }
            return (prevStart, yearStart)
        case .all:
            return nil
        }
    }

    // MARK: - Filtered Data

    private var profileInvoices: [Invoice] {
        guard let profileId = selectedProfileId,
              let profile = profiles.first(where: { $0.publicId == profileId }) else {
            return invoices
        }
        let profileName = profile.companyName.lowercased()
        guard !profileName.isEmpty else { return invoices }
        return invoices.filter {
            ($0.senderSnapshot["company_name"]?.stringValue ?? "").lowercased() == profileName
        }
    }

    private var filteredInvoices: [Invoice] {
        guard let cutoff = filterCutoff else { return profileInvoices }
        return profileInvoices.filter { parseDate($0.issueDate).map { $0 >= cutoff } ?? false }
    }

    /// Previous period invoices (for compare)
    private var previousInvoices: [Invoice] {
        guard let range = previousPeriodRange else { return [] }
        return profileInvoices.filter {
            guard let d = parseDate($0.issueDate) else { return false }
            return d >= range.start && d < range.end
        }
    }

    // MARK: - Dominant Currency

    private var dominantCurrency: String {
        var counts: [String: Int] = [:]
        for inv in filteredInvoices { counts[inv.currency, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key ?? selectedProfile?.defaultCurrency ?? "USD"
    }

    private var currencyInvoices: [Invoice] { filteredInvoices.filter { $0.currency == dominantCurrency } }
    private var prevCurrencyInvoices: [Invoice] { previousInvoices.filter { $0.currency == dominantCurrency } }
    private var excludedCount: Int { filteredInvoices.count - currencyInvoices.count }

    private var currencySymbol: String {
        let symbols: [String: String] = [
            "USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥", "CHF": "CHF",
            "CAD": "CA$", "AUD": "A$", "INR": "₹", "BRL": "R$", "SEK": "kr",
            "NOK": "kr", "DKK": "kr", "PLN": "zł", "TRY": "₺", "ZAR": "R",
            "KRW": "₩", "SGD": "S$", "HKD": "HK$", "NZD": "NZ$", "ILS": "₪",
        ]
        return symbols[dominantCurrency] ?? dominantCurrency
    }

    private var selectedProfile: BusinessProfile? {
        guard let id = selectedProfileId else { return nil }
        return profiles.first(where: { $0.publicId == id })
    }

    // MARK: - Stats

    private var paidTotal: Double {
        currencyInvoices.filter { $0.status == "paid" }.compactMap { Double($0.total) }.reduce(0, +)
    }
    private var prevPaidTotal: Double {
        prevCurrencyInvoices.filter { $0.status == "paid" }.compactMap { Double($0.total) }.reduce(0, +)
    }

    private var unpaid: Double {
        currencyInvoices.filter { $0.status == "sent" || $0.status == "overdue" }.compactMap { Double($0.total) }.reduce(0, +)
    }
    private var prevUnpaid: Double {
        prevCurrencyInvoices.filter { $0.status == "sent" || $0.status == "overdue" }.compactMap { Double($0.total) }.reduce(0, +)
    }

    private var draftInvoices: [Invoice] { filteredInvoices.filter { $0.status == "draft" } }

    // MARK: - Insights

    private var collectionRate: Double {
        let nonDraft = filteredInvoices.filter { $0.status != "draft" }
        guard !nonDraft.isEmpty else { return 0 }
        return Double(nonDraft.filter { $0.status == "paid" }.count) / Double(nonDraft.count) * 100
    }
    private var prevCollectionRate: Double {
        let nonDraft = previousInvoices.filter { $0.status != "draft" }
        guard !nonDraft.isEmpty else { return 0 }
        return Double(nonDraft.filter { $0.status == "paid" }.count) / Double(nonDraft.count) * 100
    }

    private var avgPaymentDays: Int? {
        calcAvgDays(filteredInvoices.filter { $0.status == "paid" })
    }
    private var prevAvgPaymentDays: Int? {
        calcAvgDays(previousInvoices.filter { $0.status == "paid" })
    }

    private func calcAvgDays(_ paid: [Invoice]) -> Int? {
        guard !paid.isEmpty else { return nil }
        let cal = Calendar.current
        var totalDays = 0; var count = 0
        for inv in paid {
            guard let issued = parseDate(inv.issueDate) else { continue }
            let paidDate: Date
            if !inv.updatedAt.isEmpty, let d = parseDateTime(inv.updatedAt) { paidDate = d }
            else if let due = parseDate(inv.dueDate) { paidDate = due }
            else { continue }
            totalDays += max(cal.dateComponents([.day], from: issued, to: paidDate).day ?? 0, 0); count += 1
        }
        return count > 0 ? totalDays / count : nil
    }

    private var topClients: [(name: String, amount: Double)] {
        var totals: [String: Double] = [:]
        for inv in currencyInvoices where inv.status == "paid" {
            let name = inv.clientName.isEmpty ? "Unknown" : inv.clientName
            totals[name, default: 0] += Double(inv.total) ?? 0
        }
        return totals.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
    }

    // MARK: - Change helpers

    private func changePercent(current: Double, previous: Double) -> Double? {
        guard previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }

    private func changeBadge(_ current: Double, _ previous: Double) -> some View {
        Group {
            if showCompare, let pct = changePercent(current: current, previous: previous) {
                Text(pct >= 0 ? "+\(String(format: "%.0f", pct))%" : "\(String(format: "%.0f", pct))%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(pct >= 0 ? .green : .red)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background((pct >= 0 ? Color.green : Color.red).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private var previousPeriodLabel: String {
        switch timeRange {
        case .week:    return "vs last week"
        case .month:   return "vs last month"
        case .quarter: return "vs last quarter"
        case .year:    return "vs last year"
        case .all:     return ""
        }
    }

    // MARK: - Chart Data

    private var revenueChartData: [ChartDataPoint] {
        let cal = Calendar.current; let now = Date()
        switch timeRange {
        case .week:
            return (0..<7).compactMap { i -> ChartDataPoint? in
                guard let day = cal.date(byAdding: .day, value: i, to: weekStart), day <= now else { return nil }
                let df = DateFormatter(); df.dateFormat = "EEE"
                return ChartDataPoint(label: df.string(from: day), amount: paidOn(day, .day))
            }
        case .month:
            var points: [ChartDataPoint] = []; var cursor = monthStart
            while cursor <= now {
                let weekEnd = min(cal.date(byAdding: .day, value: 6, to: cursor) ?? cursor, now)
                let total = currencyInvoices.filter { $0.status == "paid" }
                    .filter { guard let d = parseDate($0.issueDate) else { return false }; return d >= cursor && d <= weekEnd }
                    .compactMap { Double($0.total) }.reduce(0, +)
                let df = DateFormatter(); df.dateFormat = "MMM d"
                points.append(ChartDataPoint(label: df.string(from: cursor), amount: total))
                cursor = cal.date(byAdding: .day, value: 7, to: cursor) ?? now
            }
            return points
        case .quarter:
            return (0..<3).compactMap { i -> ChartDataPoint? in
                guard let monthDate = cal.date(byAdding: .month, value: i, to: quarterStart) else { return nil }
                let df = DateFormatter(); df.dateFormat = "MMM"
                return ChartDataPoint(label: df.string(from: monthDate), amount: paidOn(monthDate, .month))
            }
        case .year:
            let currentMonth = cal.component(.month, from: now)
            return (1...currentMonth).compactMap { m -> ChartDataPoint? in
                var comps = cal.dateComponents([.year], from: now); comps.month = m; comps.day = 1
                guard let monthDate = cal.date(from: comps) else { return nil }
                let df = DateFormatter(); df.dateFormat = "MMM"
                return ChartDataPoint(label: df.string(from: monthDate), amount: paidOn(monthDate, .month))
            }
        case .all:
            return (0..<12).reversed().compactMap { i in
                guard let md = cal.date(byAdding: .month, value: -i, to: now) else { return nil }
                let df = DateFormatter(); df.dateFormat = "MMM"
                return ChartDataPoint(label: df.string(from: md), amount: paidOn(md, .month))
            }
        }
    }

    /// Previous period chart data (for compare overlay)
    private var prevChartData: [ChartDataPoint] {
        guard showCompare, let range = previousPeriodRange else { return [] }
        let cal = Calendar.current
        switch timeRange {
        case .week:
            return (0..<7).compactMap { i -> ChartDataPoint? in
                guard let day = cal.date(byAdding: .day, value: i, to: range.start) else { return nil }
                guard day < range.end else { return nil }
                let total = prevCurrencyInvoices.filter { $0.status == "paid" }
                    .filter { guard let d = parseDate($0.issueDate) else { return false }; return cal.isDate(d, equalTo: day, toGranularity: .day) }
                    .compactMap { Double($0.total) }.reduce(0, +)
                let df = DateFormatter(); df.dateFormat = "EEE"
                return ChartDataPoint(label: df.string(from: day), amount: total)
            }
        case .month:
            var points: [ChartDataPoint] = []; var cursor = range.start
            while cursor < range.end {
                let weekEnd = min(cal.date(byAdding: .day, value: 6, to: cursor) ?? cursor, range.end)
                let total = prevCurrencyInvoices.filter { $0.status == "paid" }
                    .filter { guard let d = parseDate($0.issueDate) else { return false }; return d >= cursor && d <= weekEnd }
                    .compactMap { Double($0.total) }.reduce(0, +)
                let df = DateFormatter(); df.dateFormat = "MMM d"
                points.append(ChartDataPoint(label: df.string(from: cursor), amount: total))
                cursor = cal.date(byAdding: .day, value: 7, to: cursor) ?? range.end
            }
            return points
        case .quarter:
            return (0..<3).compactMap { i -> ChartDataPoint? in
                guard let monthDate = cal.date(byAdding: .month, value: i, to: range.start) else { return nil }
                let total = prevCurrencyInvoices.filter { $0.status == "paid" }
                    .filter { guard let d = parseDate($0.issueDate) else { return false }; return cal.isDate(d, equalTo: monthDate, toGranularity: .month) }
                    .compactMap { Double($0.total) }.reduce(0, +)
                let df = DateFormatter(); df.dateFormat = "MMM"
                return ChartDataPoint(label: df.string(from: monthDate), amount: total)
            }
        case .year:
            return (1...12).compactMap { m -> ChartDataPoint? in
                var comps = cal.dateComponents([.year], from: range.start); comps.month = m; comps.day = 1
                guard let monthDate = cal.date(from: comps) else { return nil }
                let total = prevCurrencyInvoices.filter { $0.status == "paid" }
                    .filter { guard let d = parseDate($0.issueDate) else { return false }; return cal.isDate(d, equalTo: monthDate, toGranularity: .month) }
                    .compactMap { Double($0.total) }.reduce(0, +)
                let df = DateFormatter(); df.dateFormat = "MMM"
                return ChartDataPoint(label: df.string(from: monthDate), amount: total)
            }
        case .all:
            return []
        }
    }

    private func paidOn(_ date: Date, _ granularity: Calendar.Component) -> Double {
        let cal = Calendar.current
        return currencyInvoices.filter { $0.status == "paid" }
            .filter { guard let d = parseDate($0.issueDate) else { return false }; return cal.isDate(d, equalTo: date, toGranularity: granularity) }
            .compactMap { Double($0.total) }.reduce(0, +)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                filterBar
                statsRow
                insightsRow
                revenueCard
                if !topClients.isEmpty { topClientsSection }
                alertsSection
                recentSection
            }
            .padding(.horizontal, hp)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle("Dashboard")
        .onAppear { Task { await loadData() } }
        .refreshable { await loadData() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greetingText).font(.subheadline).foregroundStyle(.secondary)
            if let usage = auth.usage {
                Text(usageLabel(usage)).font(.caption).foregroundStyle(.tertiary)
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

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 10) {
            if profiles.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        profileChip(label: "All", id: nil)
                        ForEach(profiles, id: \.publicId) { profile in
                            profileChip(label: profile.companyName.isEmpty ? "Unnamed" : profile.companyName, id: profile.publicId)
                        }
                    }
                }
            }

            HStack(spacing: 0) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { timeRange = range }
                    } label: {
                        Text(range.rawValue)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(timeRange == range ? Color.blue : Color.clear)
                            .foregroundStyle(timeRange == range ? .white : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(3)
            .background(Color(.systemGray5).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func profileChip(label: String, id: String?) -> some View {
        let isActive = selectedProfileId == id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedProfileId = id }
        } label: {
            Text(label)
                .font(.caption.weight(isActive ? .semibold : .regular))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isActive ? Color.blue.opacity(0.12) : Color(.systemGray6))
                .foregroundStyle(isActive ? .blue : .primary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isActive ? Color.blue.opacity(0.3) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                // Paid
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Paid").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        changeBadge(paidTotal, prevPaidTotal)
                    }
                    Text("\(currencySymbol)\(fmtC(paidTotal))")
                        .font(.title3.weight(.semibold)).foregroundStyle(.green)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background(Color(.systemGray6).opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 12))

                // Unpaid (clearer than "outstanding")
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Unpaid").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        changeBadge(unpaid, prevUnpaid)
                    }
                    Text(unpaid > 0 ? "\(currencySymbol)\(fmtC(unpaid))" : "None")
                        .font(.title3.weight(.semibold)).foregroundStyle(unpaid > 0 ? .orange : .secondary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background(Color(.systemGray6).opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if excludedCount > 0 {
                Text("\(excludedCount) invoice\(excludedCount == 1 ? "" : "s") in other currencies not included")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Insights Row

    private var insightsRow: some View {
        HStack(spacing: 10) {
            // Collection rate
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Collection").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if showCompare {
                        changeBadge(collectionRate, prevCollectionRate)
                    }
                }
                HStack(spacing: 4) {
                    Text("\(String(format: "%.0f", collectionRate))%")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(collectionRate >= 80 ? .green : collectionRate >= 50 ? .orange : .red)
                    Text("paid").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(Color(.systemGray6).opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 12))

            // Avg days to get paid
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Avg. to paid").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if showCompare, let curr = avgPaymentDays, let prev = prevAvgPaymentDays {
                        // Lower is better for payment days, so invert the color
                        let pct = changePercent(current: Double(curr), previous: Double(prev))
                        if let pct {
                            Text(pct >= 0 ? "+\(String(format: "%.0f", pct))%" : "\(String(format: "%.0f", pct))%")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(pct <= 0 ? .green : .red)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background((pct <= 0 ? Color.green : Color.red).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                HStack(spacing: 4) {
                    if let days = avgPaymentDays {
                        Text("\(days)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(days <= 14 ? .green : days <= 30 ? .blue : .orange)
                        Text("days").font(.caption2).foregroundStyle(.tertiary)
                    } else {
                        Text("--").font(.title3.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(Color(.systemGray6).opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Revenue Chart

    private var revenueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("REVENUE").font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(0.5)
                Spacer()

                // Compare toggle
                if timeRange != .all {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showCompare.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showCompare ? "arrow.left.arrow.right.circle.fill" : "arrow.left.arrow.right.circle")
                                .font(.caption)
                            Text("Compare").font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(showCompare ? .blue : .secondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(showCompare ? Color.blue.opacity(0.1) : Color(.systemGray6))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Text(dominantCurrency).font(.caption2.weight(.medium)).foregroundStyle(.tertiary)
            }

            // Compare label
            if showCompare && timeRange != .all {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.blue).frame(width: 6, height: 6)
                        Text("Current").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color(.systemGray4)).frame(width: 6, height: 6)
                        Text(previousPeriodLabel).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }

            if revenueChartData.allSatisfy({ $0.amount == 0 }) && (!showCompare || prevChartData.allSatisfy({ $0.amount == 0 })) {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar").font(.title2).foregroundStyle(.tertiary)
                    Text("Revenue appears when invoices are paid").font(.caption).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                Chart {
                    ForEach(revenueChartData) { item in
                        BarMark(x: .value("Period", item.label), y: .value("Revenue", item.amount))
                            .foregroundStyle(LinearGradient(colors: [.blue, .blue.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                            .cornerRadius(4)
                            .position(by: .value("Type", "current"))
                    }
                    if showCompare {
                        ForEach(prevChartData) { item in
                            BarMark(x: .value("Period", item.label), y: .value("Revenue", item.amount))
                                .foregroundStyle(Color(.systemGray4).opacity(0.6))
                                .cornerRadius(4)
                                .position(by: .value("Type", "previous"))
                        }
                    }
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

    // MARK: - Top Clients

    private var topClientsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOP CLIENTS").font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(0.5)
            ForEach(Array(topClients.enumerated()), id: \.offset) { index, client in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption2.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(index == 0 ? Color.blue : index == 1 ? Color.blue.opacity(0.6) : Color.blue.opacity(0.3))
                        .clipShape(Circle())
                    Text(client.name).font(.subheadline).lineLimit(1)
                    Spacer()
                    Text("\(currencySymbol)\(fmtC(client.amount))")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(index == 0 ? .blue : .primary)
                }
                .padding(.vertical, 4)
                if index < topClients.count - 1 { Divider() }
            }
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        VStack(spacing: 8) {
            if !draftInvoices.isEmpty {
                NavigationLink {
                    InvoiceListScreen(initialFilter: "draft")
                } label: {
                    alertRow(icon: "pencil.circle.fill", color: .secondary,
                             text: "\(draftInvoices.count) draft\(draftInvoices.count == 1 ? "" : "s") ready to send", detail: nil)
                }
            }
            if unpaid > 0 {
                NavigationLink {
                    InvoiceListScreen(initialFilter: "sent")
                } label: {
                    alertRow(icon: "clock.fill", color: .orange,
                             text: "\(currencySymbol)\(fmtC(unpaid)) awaiting payment", detail: nil)
                }
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
            if filteredInvoices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text").font(.title2).foregroundStyle(.tertiary)
                    Text("No invoices in this period").font(.caption).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredInvoices.prefix(5)) { invoice in
                        NavigationLink {
                            InvoiceDetailScreen(invoiceId: invoice.publicId)
                        } label: {
                            InvoiceRow(invoice: invoice)
                        }
                        .foregroundStyle(.primary).padding(.vertical, 8)
                        if invoice.id != filteredInvoices.prefix(5).last?.id { Divider() }
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

    private func parseDateTime(_ str: String) -> Date? {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: str) ?? {
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
            df.locale = Locale(identifier: "en_US_POSIX"); return df.date(from: str)
        }()
    }

    private var hp: CGFloat {
        let w = UIScreen.main.bounds.width; if w > 430 { return 24 }; if w > 390 { return 20 }; return 16
    }

    // MARK: - Load Data

    private func loadData() async {
        if !hasLoadedOnce { isLoading = true }
        do {
            let inv = try await APIClient.shared.request(InvoiceListResponse.self, method: "GET", path: "/invoices/")
            let prof = try await APIClient.shared.request([BusinessProfile].self, method: "GET", path: "/accounts/business-profiles/")
            await MainActor.run {
                invoices = inv.results; profiles = prof
                isLoading = false; hasLoadedOnce = true
            }
            await auth.refreshMe()
        } catch {
            await MainActor.run { isLoading = false; hasLoadedOnce = true }
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID(); let label: String; let amount: Double
}
