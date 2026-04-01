import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "doc.text.fill")
                    .resizable()
                    .frame(width: 60, height: 80)
                    .foregroundColor(.blue)
                    .padding()
                
                Text("Welcome to Invoicor")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Your first professional invoice is just a tap away.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()

                Spacer()
                
                Button(action: {
                    // We will build the editor next!
                }) {
                    Text("Create New Invoice")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Invoices")
        }
    }
}

#Preview {
    DashboardView()
}
