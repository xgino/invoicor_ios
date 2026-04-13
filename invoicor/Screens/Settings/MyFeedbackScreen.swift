// Screens/MyFeedbackScreen.swift
// Shows the user's submitted feedback with status updates.
// Uses SubPageLayout for consistent sub-page navigation.

import SwiftUI

struct MyFeedbackScreen: View {
    @Environment(\.dismiss) private var dismiss

    @State private var items: [FeedbackResponse] = []
    @State private var isLoading = true

    var body: some View {
        SubPageLayout(title: "My Submissions", onBack: { dismiss() }) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else if items.isEmpty {
                emptyView
            } else {
                feedbackList
            }
        }
        .task { await load() }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No submissions yet")
                .font(.headline)
            Text("Your feedback and bug reports will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Feedback List

    private var feedbackList: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 10) {
                    // Type + Status badges
                    HStack {
                        badge(
                            icon: typeIcon(item.type),
                            text: item.type.capitalized,
                            color: typeColor(item.type)
                        )
                        Spacer()
                        badge(
                            text: statusLabel(item.status),
                            color: statusColor(item.status)
                        )
                    }

                    // Subject
                    Text(item.subject)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)

                    // Message preview
                    Text(item.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    // Date
                    Text(formatDate(item.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(16)

                if item.id != items.last?.id {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .background(Color(.systemGray6).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Badge Component

    private func badge(icon: String? = nil, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Load

    private func load() async {
        do {
            let fetched = try await APIClient.shared.request(
                [FeedbackResponse].self, method: "GET",
                path: "/feedback/mine/"
            )
            await MainActor.run {
                items = fetched
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    // MARK: - Helpers

    private func typeIcon(_ type: String) -> String {
        switch type {
        case "bug":       return "ladybug.fill"
        case "feature":   return "lightbulb.fill"
        case "question":  return "questionmark.circle.fill"
        case "complaint": return "exclamationmark.bubble.fill"
        default:          return "ellipsis.circle.fill"
        }
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "bug":       return .red
        case "feature":   return .yellow
        case "question":  return .blue
        case "complaint": return .orange
        default:          return .gray
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "new":         return "New"
        case "seen":        return "Seen"
        case "in_progress": return "In Progress"
        case "resolved":    return "Resolved"
        case "wont_fix":    return "Closed"
        default:            return status.capitalized
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "new":         return .blue
        case "seen":        return .orange
        case "in_progress": return .purple
        case "resolved":    return .green
        case "wont_fix":    return .gray
        default:            return .secondary
        }
    }

    private func formatDate(_ iso: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: String(iso.prefix(19))) else { return iso }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        return display.string(from: date)
    }
}
