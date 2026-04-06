// Components/StatusBadge.swift
// Colored pill showing invoice status.
//
// Usage:
//   StatusBadge(status: invoice.status)
//   StatusBadge(status: "paid")
import SwiftUI

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status.lowercased() {
        case "draft":     return .gray
        case "sent":      return .blue
        case "paid":      return .green
        case "overdue":   return .red
        case "cancelled": return .secondary
        default:          return .gray
        }
    }
}
