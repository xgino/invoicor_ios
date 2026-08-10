// Components/ReviewGateSheet.swift
// Yes/No review gate. Yes → Apple review. No → Feedback form.
//
// THREE STATES:
// 1. Gate:     "Enjoying Invoicor?" [Yes] [Not really] [Not now]
// 2. Feedback: "What could be better?" [text field] [Send] [Skip]
// 3. Sent:     "Thanks!" [Done]
//
// The feedback form POSTs to /feedback/ API using the Feedback model.
// Type is set to "complaint" so you can filter these in Django admin.
// Screen is "review_gate" so you know WHERE the feedback came from.

import SwiftUI

struct ReviewGateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showFeedback = false
    @State private var feedbackMessage = ""
    @State private var isSending = false
    @State private var sent = false

    var body: some View {
        NavigationStack {
            if sent {
                sentView
            } else if showFeedback {
                feedbackView
            } else {
                gateView
            }
        }
        .interactiveDismissDisabled(isSending)
    }

    // MARK: - Gate (Yes / No)
    // This is the first screen. Two paths:
    // "Yes" → dismiss sheet → show Apple review popup (1.5s delay for smooth transition)
    // "Not really" → slide to feedback form
    // "Not now" → dismiss, nothing happens, try again at next milestone

    private var gateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 48))
                .foregroundStyle(.pink)

            Text("Enjoying Invoicor?")
                .font(.title2.weight(.bold))

            Text("Your feedback helps us improve.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Button {
                    // Dismiss sheet first, then show Apple review
                    // Delay needed because Apple popup can't show over a sheet
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        ReviewManager.requestReview()
                    }
                } label: {
                    Text("Yes, I love it!")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    withAnimation { showFeedback = true }
                } label: {
                    Text("Not really")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Not now") { dismiss() }
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Feedback Form
    // Shows when user taps "Not really"
    // If they type something → POST to /feedback/ API
    // If empty and they tap button → dismiss (skip)
    // Subject is "Review Gate Feedback" so you can filter in Django admin

    private var feedbackView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "envelope.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("What could be better?")
                .font(.title3.weight(.bold))

            Text("We read every message.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextEditor(text: $feedbackMessage)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Button {
                    let trimmed = feedbackMessage.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    if trimmed.isEmpty {
                        dismiss()
                    } else {
                        sendFeedback()
                    }
                } label: {
                    HStack {
                        if isSending {
                            ProgressView().tint(.white)
                        }
                        Text(feedbackMessage.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty ? "Skip" : "Send Feedback")
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSending)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Sent Confirmation
    // Shows briefly after feedback is sent. User taps Done to dismiss.

    private var sentView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Thanks for your feedback!")
                .font(.title3.weight(.bold))

            Text("We'll use it to make Invoicor better.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Send Feedback via API
    // POSTs to /feedback/ endpoint using your existing Feedback model.
    // type: "complaint" (filterable in Django admin)
    // screen: "review_gate" (so you know it came from review prompt)
    // Device info auto-captured for debugging.
    // If API fails, still show "Thanks" - don't frustrate the user.

    private func sendFeedback() {
        isSending = true
        Task {
            do {
                let body: [String: Any] = [
                    "type": "complaint",
                    "subject": "Review Gate Feedback",
                    "message": feedbackMessage,
                    "screen": "review_gate",
                    "device_model": UIDevice.current.model,
                    "os_version": UIDevice.current.systemVersion,
                    "app_version": Bundle.main.infoDictionary?[
                        "CFBundleShortVersionString"
                    ] as? String ?? "",
                ]
                let _ = try await APIClient.shared.request(
                    FeedbackResponse.self,
                    method: "POST",
                    path: "/feedback/",
                    body: body
                )
                await MainActor.run {
                    isSending = false
                    withAnimation { sent = true }
                }
            } catch {
                // Show success even if API fails
                // User did their part, don't punish them
                await MainActor.run {
                    isSending = false
                    withAnimation { sent = true }
                }
            }
        }
    }
}
