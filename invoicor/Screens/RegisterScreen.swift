// Screens/RegisterScreen.swift
// Registration sheet. Opened from LoginScreen's "Create one" link.
// On success: auto-logs in → RootView switches to authenticated state.
import SwiftUI

struct RegisterScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                FormField(
                    label: "Email",
                    text: $email,
                    placeholder: "you@email.com",
                    keyboard: .emailAddress,
                    autocap: .never
                )
                SecureFormField(
                    label: "Password",
                    text: $password,
                    placeholder: "Minimum 8 characters"
                )

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ButtonPrimary(
                    title: "Create Account",
                    isLoading: isLoading,
                    isDisabled: email.isEmpty || password.count < 8
                ) {
                    doRegister()
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func doRegister() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                try await AuthManager.shared.register(email: email, password: password)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Registration failed"
                    isLoading = false
                }
            }
        }
    }
}
