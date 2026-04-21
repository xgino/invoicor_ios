// Screens/Auth/LoginScreen.swift
// Auth screen: Apple Sign In + email/password.
//
// App icon: Add your icon to Assets.xcassets as "AppLogo" image set.

import SwiftUI
import AuthenticationServices

struct LoginScreen: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showRegister = false
    @State private var showEmailForm = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Branding
            VStack(spacing: 12) {
                Image("AppLogo")
                    .resizable().scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                Text("Invoicor").font(.title.weight(.bold))
                Text("Create & send professional invoices")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.bottom, 40)

            // Apple Sign In
            VStack(spacing: 12) {
                AppleSignInButton()
            }
            .padding(.horizontal, 24)

            // Divider
            HStack {
                Rectangle().fill(Color(.systemGray4)).frame(height: 0.5)
                Text("or").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
                Rectangle().fill(Color(.systemGray4)).frame(height: 0.5)
            }
            .padding(.horizontal, 24).padding(.vertical, 20)

            // Email
            if showEmailForm {
                emailForm
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { showEmailForm = true }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill").font(.body)
                        Text("Continue with Email").font(.body.weight(.medium))
                    }
                    .foregroundStyle(.primary).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            // Footer
            VStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("Don't have an account?").foregroundStyle(.secondary)
                    Button("Create one") { showRegister = true }.fontWeight(.medium)
                }.font(.subheadline)

                Text("By continuing you agree to our [Terms](https://invoicor.com/terms) & [Privacy Policy](https://invoicor.com/privacy)")
                    .font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center).tint(.secondary)
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .sheet(isPresented: $showRegister) { RegisterScreen() }
    }

    private var emailForm: some View {
        VStack(spacing: 14) {
            StyledFormField("Email", text: $email, placeholder: "you@email.com", keyboard: .emailAddress, autocap: .never)
            SecureFormField(label: "Password", text: $password, placeholder: "Enter password")

            if !errorMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle").font(.caption)
                    Text(errorMessage).font(.caption)
                }.foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
            }

            ButtonPrimary(title: "Sign In", isLoading: isLoading, isDisabled: email.isEmpty || password.isEmpty) {
                doLogin()
            }
        }
        .padding(.horizontal, 24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func doLogin() {
        isLoading = true; errorMessage = ""
        Task {
            do { try await AuthManager.shared.login(email: email, password: password) }
            catch { await MainActor.run { errorMessage = (error as? APIError)?.errorDescription ?? "Login failed"; isLoading = false } }
        }
    }
}

// MARK: - Apple Sign In

struct AppleSignInButton: View {
    private let delegate = AppleSignInDelegate()
    
    var body: some View {
        Button {
            delegate.startSignIn()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.body.weight(.medium))
                Text("Continue with Apple")
                    .font(.body.weight(.medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

class AppleSignInDelegate: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    func startSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow })
        else {
            return UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first ?? UIWindow()
        }
        return window
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = cred.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else { return }

        let fullName = [cred.fullName?.givenName, cred.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")

        Task {
            do {
                try await AuthManager.shared.loginWithApple(
                    identityToken: identityToken,
                    fullName: fullName.isEmpty ? nil : fullName,
                    email: cred.email
                )
            } catch {
                #if DEBUG
                print("❌ Apple Sign In failed: \(error)")
                #endif
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
            #if DEBUG
            print("❌ Apple auth error: \(error)")
            #endif
        }
    }
}
