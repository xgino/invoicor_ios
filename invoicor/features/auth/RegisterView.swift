import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel = AuthViewModel()
    
    // This allows the screen to pop itself off the stack and go back to Login
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            
            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 30)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            TextField("Email Address", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            // Password 1
            SecureField("Password", text: $viewModel.password)
                .textContentType(.oneTimeCode) // 👈 This kills the yellow suggestion box
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            // Password 2 (Confirm)
            SecureField("Confirm Password", text: $viewModel.confirmPassword)
                .textContentType(.oneTimeCode) // 👈 Add it here too
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            Button(action: {
                Task { await viewModel.register() }
            }) {
                ZStack {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Sign Up")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(viewModel.isLoading)
            .padding(.top, 10)
            
            Spacer()
            
            Button(action: {
                dismiss() // Triggers the back animation
            }) {
                Text("Already have an account? **Log in**")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .navigationBarBackButtonHidden(true) // Hides the default iOS `< Back` button at the top
    }
}

#Preview {
    RegisterView()
}
