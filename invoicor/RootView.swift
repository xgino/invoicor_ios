// RootView.swift
// Onboarding removed — goes straight to dashboard after login.
// Business profile editing happens in Settings.
import SwiftUI

struct RootView: View {
    var auth = AuthManager.shared
    @State private var splashDone = false

    var body: some View {
        Group {
            if !splashDone {
                SplashScreen {
                    withAnimation { splashDone = true }
                }
            } else {
                switch auth.state {
                case .loading:
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .unauthenticated:
                    LoginScreen()
                        .transition(.opacity)
                case .authenticated:
                    MainTabView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.state)
    }
}

// MARK: - Main Tab Bar

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showCreate = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeScreen() }
                .tabItem { Image(systemName: "house.fill"); Text("Home") }
                .tag(0)

            NavigationStack { InvoiceListScreen() }
                .tabItem { Image(systemName: "doc.text.fill"); Text("Invoices") }
                .tag(1)

            Text("")
                .tabItem { Image(systemName: "plus.circle.fill"); Text("Create") }
                .tag(2)

            NavigationStack { ClientListScreen() }
                .tabItem { Image(systemName: "person.2.fill"); Text("Clients") }
                .tag(3)

            NavigationStack { SettingsScreen() }
                .tabItem { Image(systemName: "gearshape.fill"); Text("Settings") }
                .tag(4)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                selectedTab = oldValue
                showCreate = true
            }
        }
        .fullScreenCover(isPresented: $showCreate) {
            CreateInvoiceScreen(isPresented: $showCreate)
        }
    }
}
