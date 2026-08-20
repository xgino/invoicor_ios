// Screens/Auth/LoginScreen.swift
// Auth screen: Apple + Google Sign In + email/password.
//
// App icon: Add your icon to Assets.xcassets as "AppLogo" image set.
// GoogleSignInButton lives at the bottom of this file (like AppleSignInButton),
// so both LoginScreen and RegisterScreen can use it.

import SwiftUI
import AuthenticationServices
import GoogleSignIn

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

            // Apple + Google Sign In
            VStack(spacing: 12) {
                AppleSignInButton()
                GoogleSignInButton(
                    onError: { msg in errorMessage = msg }
                )
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

// MARK: - Google Sign In
// Lives here next to Apple. Global struct, so RegisterScreen can use it too.
// Draws the real 4-color Google "G" (or uses a "GoogleLogo" asset if present).

struct GoogleSignInButton: View {
    /// Optional: called after a successful sign-in (e.g. to dismiss a sheet).
    var onSuccess: (() -> Void)? = nil
    /// Optional: surface an error message back to the parent screen.
    var onError: ((String) -> Void)? = nil

    var body: some View {
        Button {
            startGoogleSignIn()
        } label: {
            HStack(spacing: 12) {
                // Pulls the image straight from a public icon server
                AsyncImage(url: URL(string: "https://img.icons8.com/color/48/google-logo.png")) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Color.clear // Shows nothing while loading for a millisecond
                }
                .frame(width: 18, height: 18)
                
                Text("Continue with Google")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(.label))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func startGoogleSignIn() {
        guard let root = topViewController() else { return }

        GIDSignIn.sharedInstance.signIn(withPresenting: root) { result, error in
            if let error = error {
                let code = (error as NSError).code
                if code != -5 { // -5 = user cancelled; ignore quietly
                    #if DEBUG
                    print("❌ Google Sign In error: \(error)")
                    #endif
                    onError?("Google sign in failed")
                }
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                onError?("Google sign in failed")
                return
            }

            let name = [user.profile?.givenName, user.profile?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            let email = user.profile?.email

            Task {
                do {
                    try await AuthManager.shared.loginWithGoogle(
                        identityToken: idToken,
                        fullName: name.isEmpty ? nil : name,
                        email: email
                    )
                    await MainActor.run { onSuccess?() }
                } catch {
                    await MainActor.run {
                        onError?((error as? APIError)?.errorDescription ?? "Google sign in failed")
                    }
                }
            }
        }
    }

    private func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

// MARK: - Google "G" logo drawn with SwiftUI (brand colors)

struct GoogleGLogo: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let lw = s * 0.22
            ZStack {
                GoogleArc(start: -20, end: 90)
                    .stroke(Color(red: 0.20, green: 0.66, blue: 0.33), style: .init(lineWidth: lw)) // green
                GoogleArc(start: 90, end: 180)
                    .stroke(Color(red: 0.98, green: 0.74, blue: 0.02), style: .init(lineWidth: lw)) // yellow
                GoogleArc(start: 180, end: 270)
                    .stroke(Color(red: 0.92, green: 0.26, blue: 0.21), style: .init(lineWidth: lw)) // red
                GoogleArc(start: 270, end: 340)
                    .stroke(Color(red: 0.26, green: 0.52, blue: 0.96), style: .init(lineWidth: lw)) // blue
                Rectangle()
                    .fill(Color(red: 0.26, green: 0.52, blue: 0.96))
                    .frame(width: s * 0.42, height: lw)
                    .offset(x: s * 0.20, y: 0)
            }
        }
    }
}

private struct GoogleArc: Shape {
    let start: Double
    let end: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = (min(rect.width, rect.height) / 2) - (min(rect.width, rect.height) * 0.11)
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: r,
            startAngle: .degrees(start),
            endAngle: .degrees(end),
            clockwise: false
        )
        return p
    }
}
