// Components/EmptyState.swift
// "Nothing here yet" placeholder with icon, message, and optional CTA.
//
// Usage:
//   EmptyState(icon: "doc.text", title: "No invoices", message: "Create your first one")
//   EmptyState(icon: "person.2", title: "No clients", message: "Add a client", buttonTitle: "Add Client") { addClient() }
import SwiftUI

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let buttonTitle, let action {
                ButtonPrimary(title: buttonTitle, action: action)
                    .padding(.top, 8)
                    .padding(.horizontal, 40)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}
