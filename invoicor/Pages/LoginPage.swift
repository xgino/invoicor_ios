// Simplified to avoid SwiftUI type-checker complexity issues.
// The @Environment(.dismiss) error was caused by the view body
// being too complex for Swift to type-check — NOT by dismiss itself.
//
// Fix: password field uses a single SecureField (no toggle for now).
// The show/hide password toggle can be added back in a later polish step
// once everything compiles.
import SwiftUI
struct LoginPage: View {
@State private var showLogin = false
@State private var showRegister = false
var body: some View {
    VStack(spacing: 0) {
        Spacer()

        // Logo
        Image(systemName: "doc.text.fill")
            .font(.system(size: 60))
            .foregroundStyle(.blue)
            .padding(.bottom, 12)

        Text("Invoicor")
            .font(.largeTitle)
            .fontWeight(.bold)

        Text("Create invoices in seconds")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 40)

        Spacer()

        // Buttons
        Button {
            showRegister = true
        } label: {
            Text("Create Account")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)

        Button {
            showLogin = true
        } label: {
            Text("Sign In")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 24)

        Text("By continuing you agree to our Terms & Privacy Policy")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .padding(.horizontal, 24)
    }
    .sheet(isPresented: $showRegister) {
        RegisterSheet(isPresented: $showRegister)
    }
    .sheet(isPresented: $showLogin) {
        LoginSheet(isPresented: $showLogin)
    }
}
}
// MARK: - Register Sheet
struct RegisterSheet: View {
@Binding var isPresented: Bool
@State private var email = ""
@State private var password = ""
@State private var isLoading = false
@State private var errorMessage = ""
var body: some View {
    NavigationStack {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("you@email.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("Minimum 8 characters", text: $password)
                    .textFieldStyle(.roundedBorder)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                doRegister()
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                } else {
                    Text("Create Account")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.count < 8 || isLoading)

            Spacer()
        }
        .padding(24)
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { isPresented = false }
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
            await MainActor.run { isPresented = false }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Registration failed"
                isLoading = false
            }
        }
    }
}
}
// MARK: - Login Sheet
struct LoginSheet: View {
@Binding var isPresented: Bool
@State private var email = ""
@State private var password = ""
@State private var isLoading = false
@State private var errorMessage = ""
var body: some View {
    NavigationStack {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("you@email.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("Enter password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                doLogin()
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                } else {
                    Text("Sign In")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || isLoading)

            Spacer()
        }
        .padding(24)
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { isPresented = false }
            }
        }
    }
}

private func doLogin() {
    isLoading = true
    errorMessage = ""
    Task {
        do {
            try await AuthManager.shared.login(email: email, password: password)
            await MainActor.run { isPresented = false }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Login failed"
                isLoading = false
            }
        }
    }
}
}
