// Components/TemplateCard.swift
// Template selection card with live HTML thumbnail, tier badges, and lock overlay.
// Free templates: tap to preview + select.
// Locked templates: dimmed with tier badge, tap shows preview with "Upgrade" button.

import SwiftUI
import WebKit

struct TemplateCard: View {
    let template: InvoiceTemplate
    let isSelected: Bool
    let isLocked: Bool
    let onSelect: () -> Void

    @State private var showPreview = false
    @State private var previewHTML: String? = nil
    @State private var loadFailed = false

    var body: some View {
        Button { showPreview = true } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGroupedBackground))

                    if let html = previewHTML {
                        TemplateThumbView(html: html)
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

                    if isLocked {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.35))
                        Image(systemName: "lock.fill")
                            .font(.title3).foregroundStyle(.white)
                    }
                }
                .aspectRatio(0.7, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.blue : Color(.systemGray4),
                                lineWidth: isSelected ? 2.5 : 0.5)
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, .blue)
                            .padding(6)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let tier = template.tier, tier != "free", !template.tierLabel.isEmpty {
                        Text(template.tierLabel)
                            .font(.system(size: 9, weight: .bold))
                            .textCase(.uppercase).tracking(0.3)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(tierColor(tier))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                    }
                }
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)

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
                onSelect: { onSelect(); showPreview = false },
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

    private let a4Ratio: CGFloat = 210.0 / 297.0

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
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            // Preview -- A4 aspect ratio, centered, zoomable
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading preview…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else if let html = htmlContent {
                    GeometryReader { geo in
                        let available = geo.size
                        let fitWidth = min(available.width - 24, available.height * a4Ratio)
                        let fitHeight = fitWidth / a4Ratio

                        TemplateFullPreviewView(html: html)
                            .frame(width: fitWidth, height: fitHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                            .position(x: available.width / 2, y: available.height / 2)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 40)).foregroundStyle(.secondary)
                        Text(errorMessage.isEmpty ? "Preview unavailable" : errorMessage)
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 40)
                    }
                }
            }

            // Bottom bar
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    if isCurrentlySelected {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Currently selected").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                    } else if isLocked {
                        Button { showPaywall = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                Text("Upgrade to \(tierLabel)")
                            }
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent).tint(.purple)
                    } else {
                        Button(action: onSelect) {
                            Text("Select \(name)")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 16)
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
            htmlContent = cached; isLoading = false; return
        }
        do {
            let html = try await APIClient.shared.requestRaw(
                method: "GET", path: "/invoices/templates/\(slug)/preview/", auth: false)
            await MainActor.run { htmlContent = html; isLoading = false }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Failed to load preview"
                isLoading = false
            }
        }
    }
}

// MARK: - Template Thumbnail (card grid -- static, no interaction)
/// Small WKWebView for the template grid cards. No scrolling, no zoom.
/// Scales content via CSS transform to fit the tiny card frame.
private struct TemplateThumbView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.isUserInteractionEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let tag = html.hashValue
        if webView.tag != tag {
            webView.tag = tag
            let frameWidth = webView.frame.width > 0 ? webView.frame.width : 160
            let contentWidth: CGFloat = 794
            let contentHeight: CGFloat = 1123
            let scale = frameWidth / contentWidth
            let scaledHeight = contentHeight * scale
            let scaledWidth = frameWidth

            let scaleCSS = """
            <style>
                html { width: \(Int(scaledWidth))px; height: \(Int(scaledHeight))px; overflow: hidden; }
                body { width: \(Int(contentWidth))px; height: \(Int(contentHeight))px;
                       margin: 0; padding: 0;
                       transform: scale(\(scale)); transform-origin: top left; }
            </style>
            """
            var thumbHTML = html
            if thumbHTML.contains("<head>") {
                thumbHTML = thumbHTML.replacingOccurrences(of: "<head>", with: "<head>\(scaleCSS)")
            }
            webView.loadHTMLString(thumbHTML, baseURL: nil)
        }
    }
}

// MARK: - Template Full Preview (full-screen -- scrollable, zoomable)
/// Full-size WKWebView for the template preview sheet.
/// Transparent bg, hidden indicators, CSS-scaled to fit frame.
private struct TemplateFullPreviewView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 5.0
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let tag = html.hashValue
        if webView.tag != tag {
            webView.tag = tag
            let frameWidth = webView.frame.width > 0 ? webView.frame.width : UIScreen.main.bounds.width - 24
            let contentWidth: CGFloat = 794
            let contentHeight: CGFloat = 1123
            let scale = frameWidth / contentWidth
            let scaledHeight = contentHeight * scale
            let scaledWidth = frameWidth

            let scaleCSS = """
            <style>
                html { width: \(Int(scaledWidth))px; height: \(Int(scaledHeight))px; overflow: hidden; }
                body { width: \(Int(contentWidth))px; height: \(Int(contentHeight))px;
                       margin: 0; padding: 0;
                       transform: scale(\(scale)); transform-origin: top left; }
            </style>
            """
            var previewHTML = html
            if previewHTML.contains("<head>") {
                previewHTML = previewHTML.replacingOccurrences(of: "<head>", with: "<head>\(scaleCSS)")
            }
            webView.loadHTMLString(previewHTML, baseURL: nil)
        }
    }
}
