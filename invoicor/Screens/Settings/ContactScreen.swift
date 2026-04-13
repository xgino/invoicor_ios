// Screens/ContactScreen.swift
// Feedback form that POSTs to /api/feedback/
// Uses SubPageLayout for consistent navigation and layout.

import SwiftUI

struct ContactScreen: View {
    @Environment(\.dismiss) private var dismiss

    @State private var feedbackType = "feature"
    @State private var subject = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var errorMessage = ""

    private let types: [(id: String, label: String, icon: String, color: Color)] = [
        ("feature", "Feature",  "lightbulb.fill",            .yellow),
        ("bug",     "Bug",      "ladybug.fill",              .red),
        ("question","Question", "questionmark.circle.fill",  .blue),
        ("other",   "Other",    "ellipsis.circle.fill",      .gray),
    ]

    var body: some View {
        ZStack {
            SubPageLayout(
                title: "Send Feedback",
                onBack: { dismiss() }
            ) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Help us improve Invoicor")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Type selector
                typeSelector

                // Subject
                FormSection(title: "Details") {
                    StyledFormField("Subject", text: $subject, placeholder: subjectPlaceholder)
                    FormTextEditor(label: "Message", text: $message, placeholder: messagePlaceholder)
                }

                // Info
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.tertiary)
                    Text("Device info is included automatically to help us investigate.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if !errorMessage.isEmpty {
                    InlineBanner(message: errorMessage, style: .error)
                }

                // Send button
                ButtonPrimary(
                    title: "Send Feedback",
                    isLoading: isSending,
                    isDisabled: subject.isEmpty || message.isEmpty
                ) {
                    sendFeedback()
                }
            }

            // Success overlay
            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Type Selector

    private var typeSelector: some View {
        HStack(spacing: 8) {
            ForEach(types, id: \.id) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        feedbackType = type.id
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.body)
                            .foregroundStyle(feedbackType == type.id ? type.color : .secondary)
                        Text(type.label)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(feedbackType == type.id ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        feedbackType == type.id
                            ? type.color.opacity(0.08)
                            : Color(.systemGray6).opacity(0.7)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                feedbackType == type.id ? type.color.opacity(0.3) : .clear,
                                lineWidth: 1.5
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Thanks!")
                .font(.title2.weight(.bold))
            Text("We'll review your feedback shortly.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.97))
        .transition(.opacity)
    }

    // MARK: - Placeholders

    private var subjectPlaceholder: String {
        switch feedbackType {
        case "bug":      return "e.g. PDF is blank when sharing"
        case "feature":  return "e.g. Add recurring invoices"
        case "question": return "e.g. How do I change currency?"
        default:         return "What's on your mind?"
        }
    }

    private var messagePlaceholder: String {
        switch feedbackType {
        case "bug":      return "What happened? What did you expect?"
        case "feature":  return "Describe the feature you'd like to see…"
        case "question": return "What would you like to know?"
        default:         return "Tell us anything…"
        }
    }

    // MARK: - Send

    private func sendFeedback() {
        isSending = true
        errorMessage = ""

        let body: [String: Any] = [
            "type": feedbackType,
            "subject": subject,
            "message": message,
            "device_model": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "screen": "contact",
        ]

        Task {
            do {
                try await APIClient.shared.requestNoContent(
                    method: "POST",
                    path: "/feedback/",
                    body: body
                )
                await MainActor.run {
                    isSending = false
                    withAnimation { showSuccess = true }
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Failed to send. Try again."
                    isSending = false
                }
            }
        }
    }
}
