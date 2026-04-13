// Components/SubPageLayout.swift
// Consistent layout for all sub-pages (pushed from tabs).
//
// Features:
// - Hides the tab bar and navigation bar chrome
// - Custom back button (top-left) + centered title
// - Optional trailing button (top-right)
// - Optional sticky bottom action area (save button, etc.)
// - Responsive horizontal padding that adapts to screen width
//
// Usage:
//   SubPageLayout(title: "Business Profile", onBack: { dismiss() }) {
//       // scrollable content
//   } bottomBar: {
//       ButtonPrimary(title: "Save") { save() }
//   }

import SwiftUI

struct SubPageLayout<Content: View, BottomBar: View>: View {
    let title: String
    var subtitle: String? = nil
    var trailingButton: AnyView? = nil
    let onBack: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let bottomBar: BottomBar

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Bar
            header
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // MARK: - Scrollable Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    content
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 4)
                .padding(.bottom, 120)  // Space for floating bottom bar
            }

            // MARK: - Sticky Bottom Bar
            VStack(spacing: 0) {
                Divider()
                VStack(spacing: 8) {
                    bottomBar
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(.ultraThinMaterial)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }

            // Title
            VStack(spacing: 1) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            // Trailing button or spacer for centering
            if let trailing = trailingButton {
                trailing
                    .frame(width: 36, height: 36)
            } else {
                Color.clear
                    .frame(width: 36, height: 36)
            }
        }
    }

    // MARK: - Responsive Padding

    private var horizontalPadding: CGFloat {
        // Wider screens get more breathing room
        let screenWidth = UIScreen.main.bounds.width
        if screenWidth > 430 { return 24 }      // Pro Max / Plus
        if screenWidth > 390 { return 20 }      // Standard Pro
        return 16                                 // SE / Mini / older
    }
}

// MARK: - Convenience Init (No Bottom Bar)

extension SubPageLayout where BottomBar == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        trailingButton: AnyView? = nil,
        onBack: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailingButton = trailingButton
        self.onBack = onBack
        self.content = content()
        self.bottomBar = EmptyView()
    }
}

// MARK: - Form Section

/// Consistent grouped section used across all form screens.
///
/// Usage:
///   FormSection(title: "Company", footer: "Only company name is required.") {
///       FormField(label: "Name", text: $name)
///   }
struct FormSection<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 14) {
                content
            }
            .padding(16)
            .background(Color(.systemGray6).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Inline Banner

/// Success / error feedback banner, typically placed inside a bottom bar.
struct InlineBanner: View {
    let message: String
    let style: BannerStyle

    enum BannerStyle {
        case success, error
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: style.icon)
                .foregroundStyle(style.color)
            Text(message)
                .font(.callout)
                .foregroundStyle(style.color)
            Spacer()
        }
        .padding(12)
        .background(style.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
