// Screens/LoginScreen.swift
// Main auth screen after splash. Shows login form with option to switch to register.
// No separate Welcome screen — this IS the first screen after splash.
import SwiftUI

struct LoginScreen: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Logo
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                    .padding(.bottom, 8)
                Text("Invoicor")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Create invoices in seconds")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 32)

                // Form
                VStack(spacing: 16) {
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
                        placeholder: "Enter password"
                    )

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ButtonPrimary(
                        title: "Sign In",
                        isLoading: isLoading,
                        isDisabled: email.isEmpty || password.isEmpty
                    ) {
                        doLogin()
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Footer: switch to register
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundStyle(.secondary)
                    Button("Create one") {
                        showRegister = true
                    }
                    .fontWeight(.medium)
                }
                .font(.subheadline)
                .padding(.bottom, 16)

                Text("By continuing you agree to our Terms & Privacy Policy")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            .sheet(isPresented: $showRegister) {
                RegisterScreen()
            }
        }
    }

    private func doLogin() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                try await AuthManager.shared.login(email: email, password: password)
                // RootView detects .authenticated and switches automatically
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Login failed"
                    isLoading = false
                }
            }
        }
    }
}
