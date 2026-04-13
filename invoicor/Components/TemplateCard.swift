// Components/TemplateCard.swift
// Template selection card with live HTML thumbnail, tier badges, and lock overlay.
// Free templates: tap to preview + select.
// Locked templates: dimmed with tier badge, tap shows preview with "Upgrade" button.

import SwiftUI

struct TemplateCard: View {
    let template: InvoiceTemplate
    let isSelected: Bool
    let isLocked: Bool          // true if user's tier is too low
    let onSelect: () -> Void

    @State private var showPreview = false
    @State private var previewHTML: String? = nil
    @State private var loadFailed = false

    var body: some View {
        Button { showPreview = true } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)

                    if let html = previewHTML {
                        HTMLView(content: html, interactive: false)
                            .allowsHitTesting(false)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else if loadFailed {
                        VStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.title3).foregroundStyle(.secondary)
                            Text(template.name)
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    } else {
                        ProgressView().scaleEffect(0.6)
                    }

                    // Lock overlay for restricted templates
                    if isLocked {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.35))

                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
                .aspectRatio(0.7, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected ? Color.blue : Color(.systemGray4),
                            lineWidth: isSelected ? 2.5 : 0.5
                        )
                )
                // Selected checkmark (top-right)
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, .blue)
                            .padding(6)
                    }
                }
                // Tier badge (top-left) — only for non-free templates
                .overlay(alignment: .topLeading) {
                    if let tier = template.tier, tier != "free", !template.tierLabel.isEmpty {
                        Text(template.tierLabel)
                            .font(.system(size: 9, weight: .bold))
                            .textCase(.uppercase)
                            .tracking(0.3)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(tierColor(tier))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                    }
                }
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)

                // Name
                Text(template.name)
                    .font(.caption.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .task { await loadThumbnail() }
        .fullScreenCover(isPresented: $showPreview) {
            TemplatePreviewScreen(
                slug: template.slug,
                name: template.name,
                tierLabel: template.tierLabel,
                isCurrentlySelected: isSelected,
                isLocked: isLocked,
                cachedHTML: previewHTML,
                onSelect: {
                    onSelect()
                    showPreview = false
                },
                onDismiss: { showPreview = false }
            )
        }
    }

    private func loadThumbnail() async {
        do {
            let html = try await APIClient.shared.requestRaw(
                method: "GET",
                path: "/invoices/templates/\(template.slug)/preview/",
                auth: false
            )
            await MainActor.run { previewHTML = html }
        } catch {
            await MainActor.run { loadFailed = true }
        }
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier.lowercased() {
        case "starter": return .blue
        case "pro":     return .purple
        case "business": return .orange
        default:        return .gray
        }
    }
}

// MARK: - Full-Screen Template Preview

struct TemplatePreviewScreen: View {
    let slug: String
    let name: String
    let tierLabel: String
    let isCurrentlySelected: Bool
    let isLocked: Bool
    let cachedHTML: String?
    let onSelect: () -> Void
    let onDismiss: () -> Void

    @State private var htmlContent: String? = nil
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                Spacer()
                HStack(spacing: 6) {
                    Text(name).font(.headline)
                    if !tierLabel.isEmpty {
                        Text(tierLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(isLocked ? Color.purple : Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Preview
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading preview…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let html = htmlContent {
                    HTMLView(content: html, interactive: true)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 12)
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 40)).foregroundStyle(.secondary)
                        Text(errorMessage.isEmpty ? "Preview unavailable" : errorMessage)
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Bottom bar
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    if isCurrentlySelected {
                        // Already selected
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Currently selected").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                    } else if isLocked {
                        // Locked — show upgrade button
                        Button { showPaywall = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                Text("Upgrade to \(tierLabel)")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    } else {
                        // Available — select button
                        Button(action: onSelect) {
                            Text("Select \(name)")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(.ultraThinMaterial)
        }
        .background(Color(.systemGroupedBackground))
        .task { await loadPreview() }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallScreen(tier: tierLabel.lowercased())
        }
    }

    private func loadPreview() async {
        if let cached = cachedHTML {
            htmlContent = cached
            isLoading = false
            return
        }
        do {
            let html = try await APIClient.shared.requestRaw(
                method: "GET",
                path: "/invoices/templates/\(slug)/preview/",
                auth: false
            )
            await MainActor.run { htmlContent = html; isLoading = false }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Failed to load preview"
                isLoading = false
            }
        }
    }
}
