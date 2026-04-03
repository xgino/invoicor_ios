// Navigation root. Shows login, onboarding, or main app based on state.
// MainTabView and SettingsStub also live here (related, same file).
import SwiftUI
struct RootView: View {
var auth = AuthManager.shared
@AppStorage("has_completed_onboarding") private var hasOnboarded = true
// ↑ Set to true for development. Change to false when SetupPage is built.
var body: some View {
    Group {
        switch auth.state {
        case .loading:
            // App just launched, validating stored token
            ProgressView("Loading...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .unauthenticated:
            LoginPage()

        case .authenticated:
            if hasOnboarded {
                MainTabView()
            } else {
                // Placeholder until SetupPage is built (Step 8)
                VStack(spacing: 20) {
                    Text("Setup — Coming Soon")
                        .font(.title)
                    Button("Skip for now") {
                        hasOnboarded = true
                    }
                }
            }
        }
    }
    .animation(.easeInOut(duration: 0.3), value: auth.state == .authenticated)
}
}
// MARK: - Main Tab Bar
struct MainTabView: View {
@State private var selectedTab = 0
@State private var showCreate = false
var body: some View {
    TabView(selection: $selectedTab) {
        // Tab 0: Dashboard
        NavigationStack {
            Text("Dashboard — Build in Step 4")
                .navigationTitle("Home")
        }
        .tabItem { Label("Home", systemImage: "house.fill") }
        .tag(0)

        // Tab 1: Invoices
        NavigationStack {
            Text("Invoice History — Build in Step 5")
                .navigationTitle("Invoices")
        }
        .tabItem { Label("Invoices", systemImage: "doc.text.fill") }
        .tag(1)

        // Tab 2: Create (empty — triggers modal)
        Color.clear
            .tabItem { Label("Create", systemImage: "plus.circle.fill") }
            .tag(2)

        // Tab 3: Assets
        NavigationStack {
            Text("Clients — Build in Step 7")
                .navigationTitle("Assets")
        }
        .tabItem { Label("Assets", systemImage: "person.2.fill") }
        .tag(3)

        // Tab 4: Settings (with working logout for testing)
        NavigationStack {
            SettingsStub()
        }
        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        .tag(4)
    }
    // Intercept the center + tab to show a modal instead
    .onChange(of: selectedTab) { _, newValue in
        if newValue == 2 {
            selectedTab = 0
            showCreate = true
        }
    }
    .fullScreenCover(isPresented: $showCreate) {
        NavigationStack {
            Text("Create Invoice — Build in Step 6")
                .navigationTitle("New Invoice")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showCreate = false }
                    }
                }
        }
    }
}
}
// MARK: - Temporary Settings (with working Logout for testing)
private struct SettingsStub: View {
var auth = AuthManager.shared
var body: some View {
    List {
        if let user = auth.currentUser {
            Section("Account") {
                LabeledContent("Email", value: user.email)
                LabeledContent("Plan", value: user.tier.capitalized)
                LabeledContent("Invoice Prefix", value: user.invoicePrefix)
            }
        }

        if let usage = auth.usage, let limits = auth.limits {
            Section("Usage") {
                if let limit = usage.invoicesLimit {
                    LabeledContent("Invoices", value: "\(usage.invoicesUsed) of \(limit)")
                } else {
                    LabeledContent("Invoices", value: "\(usage.invoicesUsed) (unlimited)")
                }
                LabeledContent("Max profiles", value: "\(limits.businessProfiles)")
                LabeledContent("Analytics", value: limits.analytics ? "Yes" : "Locked")
            }
        }

        Section {
            Button("Log Out", role: .destructive) {
                auth.logout()
            }
        }
    }
    .navigationTitle("Settings")
}
}
// 
