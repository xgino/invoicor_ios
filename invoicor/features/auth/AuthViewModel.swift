import Foundation
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    @Published var isAuthenticated = false
    
    // --- LOGIN ---
    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            self.errorMessage = "Please enter email and password."
            return
        }
        // 👇 Notice we use .login here now!
        await authenticate(endpoint: .login, data: ["email": email, "password": password])
    }
    
    // --- REGISTER ---
    func register() async {
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            self.errorMessage = "Please fill in all fields."
            return
        }
        
        guard password == confirmPassword else {
            self.errorMessage = "Passwords do not match."
            return
        }
        
        // 👇 Notice we use .register here now!
        await authenticate(endpoint: .register, data: ["email": email, "password": password])
    }
    
    // --- THE API WORKER ---
    // 👇 Notice we changed String to APIEndpoint here!
    private func authenticate(endpoint: APIEndpoint, data: [String: String]) async {
        isLoading = true
        errorMessage = nil
        
        guard let body = try? JSONEncoder().encode(data) else { return }
        
        do {
            let response: AuthResponse = try await APIManager.shared.request(
                endpoint: endpoint,
                method: "POST",
                body: body
            )
            
            // 1. Handle Register Success
            if let pubId = response.publicId {
                print("✅ Registered User: \(pubId)")
            }
            
            // 2. Handle Login Success (Token received)
            if let token = response.token {
                print("✅ Login Success! Token: \(token)")
                // Here is where you will eventually save the token to the Keychain
                self.isAuthenticated = true
            }
            
            // For now, let's just let them in if EITHER register or login works
            if response.publicId != nil || response.token != nil {
                self.isAuthenticated = true
            }
            
            self.isLoading = false
            
        } catch let error as APIError {
            // 👇 Now it passes Django's exact words to the screen!
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            print("🚨 Auth Error: \(error.localizedDescription)")
            
        } catch {
            self.errorMessage = "An unexpected error occurred."
            self.isLoading = false
        }
    }
}
