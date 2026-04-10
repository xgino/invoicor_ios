// Screens/SettingsScreen.swift
// Tab 5: Settings — account, subscription, support, legal, danger zone.
// No more stubs — this is the final version.
import SwiftUI
import RevenueCatUI

struct SettingsScreen: View {
    var auth = AuthManager.shared
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showPaywall = false

    var body: some View {
        List {
            // Account
            Section {
                NavigationLink {
                    BusinessProfileScreen()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "building.2")
                            .font(.body)
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Business Profile")
                            Text(auth.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Account")
            }

            // Subscription
            Section {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.body)
                            .foregroundStyle(.orange)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(planName)
                                .foregroundStyle(.primary)
                            if let usage = auth.usage {
                                if let limit = usage.invoicesLimit {
                                    Text("\(usage.invoicesUsed) of \(limit) invoices used")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(usage.invoicesUsed) invoices created")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                        if auth.currentUser?.tier == "free" {
                            Text("Upgrade")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                }
            } header: {
                Text("Subscription")
            }

            // Saved Products
            Section {
                NavigationLink {
                    SavedProductsScreen()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "archivebox")
                            .font(.body)
                            .foregroundStyle(.purple)
                            .frame(width: 28)
                        Text("Saved Products")
                    }
                }
            } header: {
                Text("Library")
            }

            // Support
            Section {
                Link(destination: URL(string: "https://invoicor.com/help")!) {
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .font(.body)
                            .foregroundStyle(.green)
                            .frame(width: 28)
                        Text("Help & FAQ")
                            .foregroundStyle(.primary)
                    }
                }
                Link(destination: URL(string: "mailto:info@invoicor.com")!) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope")
                            .font(.body)
                            .foregroundStyle(.green)
                            .frame(width: 28)
                        Text("Contact Support")
                            .foregroundStyle(.primary)
                    }
                }
            } header: {
                Text("Support")
            }

            // Legal
            Section {
                Link(destination: URL(string: "https://invoicor.com/terms")!) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                        Text("Terms of Service")
                            .foregroundStyle(.primary)
                    }
                }
                Link(destination: URL(string: "https://invoicor.com/privacy")!) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                        Text("Privacy Policy")
                            .foregroundStyle(.primary)
                    }
                }
            } header: {
                Text("Legal")
            }

            // Danger zone
            Section {
                Button {
                    showLogoutConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.body)
                            .foregroundStyle(.red)
                            .frame(width: 28)
                        Text("Log Out")
                            .foregroundStyle(.red)
                    }
                }
                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundStyle(.red)
                            .frame(width: 28)
                        Text("Delete Account")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Log Out?", isPresented: $showLogoutConfirm) {
            Button("Log Out", role: .destructive) { auth.logout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again.")
        }
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Delete Everything", role: .destructive) {
                Task { try? await auth.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and all invoices. This cannot be undone.")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(displayCloseButton: true)
        }
    }

    private var planName: String {
        switch auth.currentUser?.tier ?? "free" {
        case "free": return "Free Plan"
        case "starter": return "Starter Plan"
        case "pro": return "Pro Plan"
        case "business": return "Business Plan"
        default: return "Free Plan"
        }
    }
}
