import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    
    var body: some View {
        // The NavigationStack MUST wrap the VStack so we can transition screens
        NavigationStack {
            VStack(spacing: 20) {
                
                Text("Invoicor")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 40)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                TextField("Email Address", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none) // Stops it from capitalizing emails
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                SecureField("Password", text: $viewModel.password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                Button(action: {
                    Task { await viewModel.login() }
                }) {
                    ZStack {
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Continue")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isLoading)
                .padding(.top, 10)
                
                Spacer()
                
                // The link that pushes the RegisterView onto the screen
                NavigationLink(destination: RegisterView()) {
                    Text("Don't have an account? **Sign up**")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
    }
}

#Preview {
    LoginView()
}
