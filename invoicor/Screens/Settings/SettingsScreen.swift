// Screens/Settings/SettingsScreen.swift
// Tab 5: Settings — subscription, invoice settings, support, legal, account.
// Uses consistent card styling matching the rest of the app.

import SwiftUI

struct SettingsScreen: View {
    var auth = AuthManager.shared
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showPaywall = false
    @State private var showInvoiceSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                HStack {
                    Text("Settings").font(.largeTitle.weight(.bold))
                    Spacer()
                }
                .padding(.horizontal, hp).padding(.top, 8)

                // Account info
                accountSection

                // Subscription
                subscriptionSection

                // Invoice settings
                invoiceSettingsSection

                // Support
                supportSection

                // Legal
                legalSection

                // Danger zone
                dangerSection

                // App version
                Text("Invoicor v\(appVersion) • Build \(buildNumber)")
                    .font(.caption2).foregroundStyle(.quaternary)
                    .padding(.top, 4).padding(.bottom, 40)
            }
        }
        .alert("Log Out?", isPresented: $showLogoutConfirm) {
            Button("Log Out", role: .destructive) { auth.logout() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("You'll need to sign in again.") }
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Delete Everything", role: .destructive) { Task { try? await auth.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This permanently deletes your account and all invoices. This cannot be undone.") }
        .sheet(isPresented: $showPaywall) { PaywallScreen() }
        .sheet(isPresented: $showInvoiceSettings) { InvoiceNumberSheet() }
    }

    // MARK: - Account

    private var accountSection: some View {
        group(title: "ACCOUNT") {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.12))
                    Text(initials).font(.body.weight(.semibold)).foregroundStyle(.blue)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.currentUser?.email ?? "—").font(.body).foregroundStyle(.primary)
                    Text("Signed in").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
    }

    private var initials: String {
        let email = auth.currentUser?.email ?? "?"
        let parts = email.split(separator: "@").first ?? "?"
        return String(parts.prefix(2)).uppercased()
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        group(title: "SUBSCRIPTION") {
            Button { showPaywall = true } label: {
                HStack(spacing: 12) {
                    icon("crown.fill", color: .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(planName).font(.body).foregroundStyle(.primary)
                        if let usage = auth.usage {
                            Text(usageText(usage)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if auth.currentUser?.tier == "free" {
                        Text("Upgrade").font(.caption.weight(.semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.orange).clipShape(Capsule())
                    } else {
                        chevron
                    }
                }
            }
        }
    }

    // MARK: - Invoice Settings

    private var invoiceSettingsSection: some View {
        group(title: "INVOICING") {
            Button { showInvoiceSettings = true } label: {
                HStack(spacing: 12) {
                    icon("number", color: .indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invoice Numbering").font(.body).foregroundStyle(.primary)
                        Text("Prefix: \(auth.currentUser?.invoicePrefix ?? "INV") • Next: #\(auth.currentUser?.nextInvoiceNumber ?? 1)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    chevron
                }
            }
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        group(title: "SUPPORT") {
            NavigationLink { ContactScreen() } label: {
                row(icon: "bubble.left.and.text.bubble.right", color: .blue, title: "Send Feedback")
            }
            Divider().padding(.leading, 52)
            NavigationLink { MyFeedbackScreen() } label: {
                row(icon: "clock.arrow.circlepath", color: .teal, title: "My Submissions")
            }
            Divider().padding(.leading, 52)
            Link(destination: URL(string: "https://invoicor.com/help")!) {
                row(icon: "questionmark.circle", color: .green, title: "Help & FAQ")
            }
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        group(title: "LEGAL") {
            Link(destination: URL(string: "https://invoicor.com/terms")!) {
                row(icon: "doc.text", color: .secondary, title: "Terms of Service")
            }
            Divider().padding(.leading, 52)
            Link(destination: URL(string: "https://invoicor.com/privacy")!) {
                row(icon: "lock.shield", color: .secondary, title: "Privacy Policy")
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerSection: some View {
        VStack(spacing: 0) {
            Button { showLogoutConfirm = true } label: {
                row(icon: "rectangle.portrait.and.arrow.right", color: .red, title: "Log Out").foregroundStyle(.red)
            }
            Divider().padding(.leading, 52)
            Button { showDeleteConfirm = true } label: {
                row(icon: "trash", color: .red, title: "Delete Account").foregroundStyle(.red)
            }
        }
        .padding(4)
        .background(Color(.systemGray6).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, hp)
    }

    // MARK: - Reusable Pieces

    private func group(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(0.5)
                .padding(.horizontal, hp).padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .padding(4).background(Color(.systemGray6).opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, hp)
        }
    }

    private func row(icon iconName: String, color: Color, title: String, subtitle: String? = nil) -> some View {
        HStack(spacing: 12) {
            icon(iconName, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            chevron
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
    }

    private func icon(_ name: String, color: Color) -> some View {
        Image(systemName: name).font(.body).foregroundStyle(color)
            .frame(width: 32, height: 32).background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var chevron: some View {
        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
    }

    // MARK: - Helpers

    private var planName: String {
        switch auth.currentUser?.tier ?? "free" {
        case "free": return "Free Plan"; case "starter": return "Starter Plan"
        case "pro": return "Pro Plan"; case "business": return "Business Plan"
        default: return "Free Plan"
        }
    }

    private func usageText(_ usage: UsageInfo) -> String {
        if let l = usage.invoicesLifetimeLimit { return "\(usage.invoicesTotal) of \(l) free invoices used" }
        if let m = usage.invoicesMonthlyLimit { return "\(usage.invoicesThisMonth) of \(m) invoices this month" }
        return "\(usage.invoicesThisMonth) invoices this month"
    }

    private var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }
    private var buildNumber: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1" }
    private var hp: CGFloat {
        let w = UIScreen.main.bounds.width; if w > 430 { return 24 }; if w > 390 { return 20 }; return 16
    }
}

// MARK: - Invoice Number Settings Sheet

struct InvoiceNumberSheet: View {
    @Environment(\.dismiss) private var dismiss
    var auth = AuthManager.shared

    @State private var prefix = ""
    @State private var nextNumber = ""
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview
                    VStack(spacing: 6) {
                        Text("Preview").font(.caption).foregroundStyle(.secondary)
                        Text("\(prefix.isEmpty ? "INV" : prefix)-\(String(format: "%05d", Int(nextNumber) ?? 1))")
                            .font(.title2.weight(.bold).monospaced())
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color(.systemGray6).opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    FormSection(title: "Invoice Number Format") {
                        StyledFormField("Prefix", text: $prefix, placeholder: "INV", autocap: .characters)
                        StyledFormField("Next Number", text: $nextNumber, placeholder: "1", keyboard: .numberPad)
                    }

                    Text("The next invoice you create will use this number. Change the prefix to match your previous system (e.g. WR, ACME).")
                        .font(.caption).foregroundStyle(.tertiary).padding(.horizontal, 4)

                    if !errorMessage.isEmpty { InlineBanner(message: errorMessage, style: .error) }
                    if !successMessage.isEmpty { InlineBanner(message: successMessage, style: .success) }

                    ButtonPrimary(title: "Save", isLoading: isSaving, isDisabled: prefix.isEmpty) { save() }
                }
                .padding(20)
            }
            .navigationTitle("Invoice Numbering")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                prefix = auth.currentUser?.invoicePrefix ?? "INV"
                nextNumber = "\(auth.currentUser?.nextInvoiceNumber ?? 1)"
            }
        }
    }

    private func save() {
        isSaving = true; errorMessage = ""; successMessage = ""
        var body: [String: Any] = [:]
        body["invoice_prefix"] = prefix.trimmingCharacters(in: .whitespaces).uppercased()
        if let num = Int(nextNumber), num > 0 { body["next_invoice_number"] = num }

        Task {
            do {
                _ = try await APIClient.shared.request(User.self, method: "PUT", path: "/accounts/invoice-settings/", body: body)
                await auth.refreshMe()
                await MainActor.run { isSaving = false; withAnimation { successMessage = "Saved" } }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Failed to save"
                    isSaving = false
                }
            }
        }
    }
}
