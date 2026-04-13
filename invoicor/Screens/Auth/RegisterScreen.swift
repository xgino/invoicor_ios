// Screens/Auth/RegisterScreen.swift
// Registration: Apple Sign In + email/password.

import SwiftUI
import AuthenticationServices

struct RegisterScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    private var isValid: Bool {
        !email.isEmpty && password.count >= 8 && password == confirmPassword
    }
    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Header
                VStack(spacing: 12) {
                    Image("AppLogo")
                        .resizable().scaledToFit()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

                    Text("Create Account").font(.title2.weight(.bold))
                    Text("Start invoicing in seconds")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)

                // Apple Sign In
                AppleSignInButton()
                    .padding(.horizontal, 24)

                // Divider
                HStack {
                    Rectangle().fill(Color(.systemGray4)).frame(height: 0.5)
                    Text("or").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
                    Rectangle().fill(Color(.systemGray4)).frame(height: 0.5)
                }
                .padding(.horizontal, 24).padding(.vertical, 20)

                // Email form
                VStack(spacing: 14) {
                    StyledFormField("Email", text: $email, placeholder: "you@email.com", keyboard: .emailAddress, autocap: .never)
                    SecureFormField(label: "Password", text: $password, placeholder: "Minimum 8 characters")
                    SecureFormField(label: "Confirm Password", text: $confirmPassword, placeholder: "Re-enter password")

                    if passwordMismatch {
                        hint(icon: "exclamationmark.circle", text: "Passwords don't match", color: .red)
                    } else if !password.isEmpty && password.count < 8 {
                        hint(icon: "info.circle", text: "At least 8 characters", color: .secondary)
                    }

                    if !errorMessage.isEmpty {
                        hint(icon: "exclamationmark.circle", text: errorMessage, color: .red)
                    }

                    ButtonPrimary(title: "Create Account", isLoading: isLoading, isDisabled: !isValid) {
                        doRegister()
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Footer
                HStack(spacing: 4) {
                    Text("Already have an account?").foregroundStyle(.secondary)
                    Button("Sign In") { dismiss() }.fontWeight(.medium)
                }
                .font(.subheadline).padding(.bottom, 32)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.body.weight(.medium)).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func hint(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption)
            Text(text).font(.caption)
        }
        .foregroundStyle(color).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func doRegister() {
        isLoading = true; errorMessage = ""
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
