// Components/Buttons.swift
// All reusable button styles in one place.
//
// Usage:
//   ButtonPrimary(title: "Sign In", isLoading: loading) { doLogin() }
//   ButtonSecondary(title: "Cancel") { dismiss() }
import SwiftUI

// MARK: - Primary Button (filled blue, main actions)

struct ButtonPrimary: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Secondary Button (outlined, secondary actions)

struct ButtonSecondary: View {
    let title: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .disabled(isDisabled)
    }
}
