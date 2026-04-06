// Components/Cards.swift
// All card/row components for lists and dashboards.
//
// Usage:
//   StatCard(title: "Paid", value: "$4,500", color: .green)
//   InvoiceRow(invoice: someInvoice)
//   ClientRow(client: someClient)
import SwiftUI

// MARK: - Stat Card (dashboard number cards)

struct StatCard: View {
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .frame(minWidth: 100, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Invoice Row (used in Home, InvoiceList, ClientDetail)

struct InvoiceRow: View {
    let invoice: Invoice

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.clientName)
                    .font(.body)
                    .lineLimit(1)
                Text(invoice.invoiceNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(invoice.totalFormatted)
                    .font(.body)
                    .fontWeight(.medium)
                StatusBadge(status: invoice.status)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Client Row (used in ClientList, ClientPicker)

struct ClientRow: View {
    let client: Client

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(client.displayName)
                .font(.body)
                .lineLimit(1)
            if !client.email.isEmpty {
                Text(client.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
