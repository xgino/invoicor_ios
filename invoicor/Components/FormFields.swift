// Components/FormFields.swift
// All reusable form input components with consistent styling.
//
// Usage:
//   StyledFormField("Email", text: $email, placeholder: "you@email.com", keyboard: .emailAddress)
//   StyledFormField("Phone", text: $phone, placeholder: "+31 6 1234 5678", keyboard: .phonePad)
//   SecureFormField(label: "Password", text: $password)
//   FormTextEditor(label: "Notes", text: $notes)
//
// These match the FormSection container style from SubPageLayout.swift.

import SwiftUI

// MARK: - Styled Text Field

/// Modern form field with floating-style label above.
/// Adapts to any screen width — no overflow on small devices.
struct StyledFormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var autocap: TextInputAutocapitalization = .sentences

    init(
        _ label: String,
        text: Binding<String>,
        placeholder: String = "",
        keyboard: UIKeyboardType = .default,
        autocap: TextInputAutocapitalization = .sentences
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.keyboard = keyboard
        self.autocap = autocap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Secure Field with Show/Hide

struct SecureFormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    @State private var showPassword = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Group {
                    if showPassword {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Multiline Text Editor

struct FormTextEditor: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var minHeight: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .frame(minHeight: minHeight)
                    .padding(4)

                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Dropdown / Menu Picker

/// Styled dropdown that matches the form field look.
///
/// Usage:
///   FormPicker(label: "Currency", selection: "USD", items: currencies) { c in
///       "\(c.symbol) \(c.code) — \(c.name)"
///   } onSelect: { c in
///       selectedCurrency = c.code
///   }
struct FormPicker<Item: Identifiable>: View {
    let label: String
    let displayText: String
    let items: [Item]
    let itemLabel: (Item) -> String
    let isSelected: (Item) -> Bool
    let onSelect: (Item) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Menu {
                ForEach(items) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack {
                            Text(itemLabel(item))
                            if isSelected(item) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(displayText)
                        .foregroundStyle(displayText.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            }
        }
    }
}

// MARK: - Tappable Row (for sheet triggers like template picker)

struct FormTappableRow: View {
    let label: String
    let displayText: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(action: action) {
                HStack {
                    Text(displayText.isEmpty ? "Choose…" : displayText)
                        .foregroundStyle(displayText.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            }
        }
    }
}
