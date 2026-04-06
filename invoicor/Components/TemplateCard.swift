// Components/TemplateCard.swift
// Template preview card — shows template name with styled preview.
// HTMLView in tiny thumbnails causes WKWebView to hang,
// so we use a styled placeholder that looks like a mini invoice.
import SwiftUI

struct TemplateCard: View {
    let template: InvoiceTemplate
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Mini invoice preview placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .aspectRatio(0.7, contentMode: .fit)
                    .overlay(
                        VStack(alignment: .leading, spacing: 6) {
                            // Mini header
                            HStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(.systemGray4))
                                    .frame(width: 40, height: 6)
                                Spacer()
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(.systemGray3))
                                    .frame(width: 50, height: 10)
                            }

                            Spacer().frame(height: 4)

                            // Mini address blocks
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    RoundedRectangle(cornerRadius: 1).fill(Color(.systemGray5)).frame(width: 30, height: 3)
                                    RoundedRectangle(cornerRadius: 1).fill(Color(.systemGray5)).frame(width: 45, height: 3)
                                    RoundedRectangle(cornerRadius: 1).fill(Color(.systemGray5)).frame(width: 35, height: 3)
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 3) {
                                    RoundedRectangle(cornerRadius: 1).fill(Color(.systemGray5)).frame(width: 30, height: 3)
                                    RoundedRectangle(cornerRadius: 1).fill(Color(.systemGray5)).frame(width: 45, height: 3)
                                }
                            }

                            Spacer().frame(height: 6)

                            // Mini table header
                            Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                            HStack {
                                RoundedRectangle(cornerRadius: 1).fill(Color(.systemGray5)).frame(height: 3)
                                RoundedRectangle(cornerRadius: 1).fill(Color(.systemGray5)).frame(width: 20, height: 3)
                                RoundedRectangle(cornerRadius: 1).fill(Color(.systemGray5)).frame(width: 20, height: 3)
                            }
                            Rectangle().fill(Color(.systemGray5)).frame(height: 0.5)

                            // Mini rows
                            ForEach(0..<3, id: \.self) { _ in
                                HStack {
                                    RoundedRectangle(cornerRadius: 1).fill(Color(.systemGray6)).frame(height: 3)
                                    RoundedRectangle(cornerRadius: 1).fill(Color(.systemGray6)).frame(width: 15, height: 3)
                                    RoundedRectangle(cornerRadius: 1).fill(Color(.systemGray6)).frame(width: 15, height: 3)
                                }
                            }

                            Spacer()

                            // Mini total
                            HStack {
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    RoundedRectangle(cornerRadius: 1).fill(Color(.systemGray5)).frame(width: 40, height: 3)
                                    Rectangle().fill(Color(.systemGray4)).frame(width: 50, height: 1)
                                    RoundedRectangle(cornerRadius: 2).fill(Color(.systemGray3)).frame(width: 50, height: 5)
                                }
                            }
                        }
                        .padding(12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color.blue : Color(.systemGray4),
                                lineWidth: isSelected ? 3 : 1
                            )
                    )
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                                .background(Circle().fill(.white))
                                .padding(6)
                        }
                    }
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)

                Text(template.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}
