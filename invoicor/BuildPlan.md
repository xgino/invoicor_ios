# Invoicor iOS — Build Plan v3 (Component-First)

---

## The Mental Model: Django → SwiftUI

```
Django                          SwiftUI
─────────────────               ─────────────────
{% include "btn.html" %}   →    ButtonPrimary(title: "Save")
{% include "field.html" %} →    FormField(label: "Email", text: $email)
base.html (layout)         →    NavShell { ... content ... }
template tags (reusable)   →    Components/ folder
views.py                   →    Screens/ folder
utils.py                   →    Helpers/ folder
```

In SwiftUI, EVERY reusable piece is a `struct View`.
You import nothing special — if it's in your project, you can use it anywhere.
No `import` needed between your own files (unlike Python modules).

---

## Project Structure (Component-First)

```
Invoicor/
├── InvoicorApp.swift                 # Entry point
├── RootView.swift                    # Router (loading → auth → tabs)
│
├── Config/
│   ├── Dev.xcconfig
│   ├── Prod.xcconfig
│   └── AppConfig.swift
│
├── Core/
│   ├── Models.swift                  # Data structs (like models.py)
│   ├── APIClient.swift               # HTTP layer
│   └── AuthManager.swift             # Auth state
│
├── Helpers/
│   └── Formatters.swift              # Date formatting, currency, etc.
│
├── Components/                       # ← Reusable building blocks
│   ├── FormField.swift               # Text input with label
│   ├── SecureFormField.swift         # Password input with label
│   ├── ButtonPrimary.swift           # Big blue button
│   ├── ButtonSecondary.swift         # Outline button
│   ├── StatusBadge.swift             # Colored pill (Draft/Sent/Paid)
│   ├── StatCard.swift                # Dashboard number card
│   ├── InvoiceRow.swift              # Invoice list item
│   ├── ClientRow.swift               # Client list item
│   ├── EmptyState.swift              # "Nothing here yet" view
│   ├── SVGView.swift                 # Renders SVG via WebView
│   └── SheetHeader.swift             # Drag handle + title for sheets
│
├── Screens/
│   │
│   │── Account/                      # Auth flow (not logged in)
│   │   ├── WelcomScreen.swift        # Logo + 2 buttons
│   │   ├── LoginScreen.swift         # Email + password → sign in
│   │   └── RegisterScreen.swift      # Email + password → create account
│   │
│   ├── Onboarding/                   # First-time setup
│   │   ├── SplashScreen.swift        # Animated welcome (2 seconds)
│   │   ├── BusinessSetupScreen.swift # Company name, email, logo
│   │   └── TemplatePickScreen.swift  # Grid of SVG templates
│   │
│   ├── Home/
│   │   └── HomeScreen.swift          # Dashboard: stats + recent list
│   │
│   ├── Invoices/
│   │   ├── InvoiceListScreen.swift   # Filtered list + search
│   │   ├── InvoiceDetailScreen.swift # SVG preview + actions
│   │   └── InvoiceShareScreen.swift  # Full SVG + share button
│   │
│   ├── Create/
│   │   ├── CreateInvoiceScreen.swift # The big form
│   │   ├── ClientPickerSheet.swift   # Select/create client
│   │   └── AddItemSheet.swift        # Add line item
│   │
│   ├── Clients/
│   │   ├── ClientListScreen.swift    # All clients
│   │   └── ClientDetailScreen.swift  # Edit client + their invoices
│   │
│   └── Settings/
│       ├── SettingsScreen.swift      # Main settings list
│       ├── BusinessProfileScreen.swift  # Edit business info
│       ├── TemplateGalleryScreen.swift  # Change template
│       └── PaywallScreen.swift       # Upgrade plans
│
└── Resources/
    ├── Assets.xcassets/
    └── Info.plist
```

**File count:**
- Components: 11 small files (each under 50 lines)
- Screens: 16 files (each one screen, one responsibility)  
- Core: 3 files
- Other: 5 files
- **Total: 35 files, all short and focused**

---

## How Components Work (This Is the Key)

### FormField.swift — Used EVERYWHERE

```swift
// Components/FormField.swift
import SwiftUI

struct FormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textFieldStyle(.roundedBorder)
        }
    }
}
```

### Now look how it's REUSED:

```swift
// LoginScreen.swift
FormField(label: "Email", text: $email, placeholder: "you@email.com", keyboard: .emailAddress)

// RegisterScreen.swift
FormField(label: "Email", text: $email, placeholder: "you@email.com", keyboard: .emailAddress)

// BusinessSetupScreen.swift  
FormField(label: "Company Name", text: $companyName, placeholder: "Acme Inc")
FormField(label: "Phone", text: $phone, placeholder: "+31 6 1234 5678", keyboard: .phonePad)

// ClientDetailScreen.swift
FormField(label: "Company", text: $companyName)
FormField(label: "Contact Name", text: $contactName)
FormField(label: "Email", text: $email, keyboard: .emailAddress)

// SettingsScreen → BusinessProfileScreen.swift
FormField(label: "Bank Name", text: $bankName)
FormField(label: "IBAN", text: $iban)
```

**One component, used in 6+ screens.** Change the style once → updates everywhere.
This is exactly like a Django template tag that you {% include %} everywhere.

### ButtonPrimary.swift — The main action button

```swift
// Components/ButtonPrimary.swift
import SwiftUI

struct ButtonPrimary: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                Text(title)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isDisabled || isLoading)
    }
}
```

### Used everywhere:

```swift
// LoginScreen.swift
ButtonPrimary(title: "Sign In", isLoading: isLoading, isDisabled: email.isEmpty) {
    doLogin()
}

// RegisterScreen.swift
ButtonPrimary(title: "Create Account", isLoading: isLoading, isDisabled: password.count < 8) {
    doRegister()
}

// BusinessSetupScreen.swift
ButtonPrimary(title: "Continue", isDisabled: companyName.isEmpty) {
    saveAndContinue()
}

// CreateInvoiceScreen.swift
ButtonPrimary(title: "Preview Invoice", isDisabled: !isValid) {
    saveAndPreview()
}
```

### InvoiceRow.swift — Used in 3 screens

```swift
// Components/InvoiceRow.swift
import SwiftUI

struct InvoiceRow: View {
    let invoice: Invoice
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.clientName)
                    .font(.body)
                Text(invoice.invoiceNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(invoice.totalFormatted)
                    .font(.body)
                    .fontWeight(.medium)
                StatusBadge(status: invoice.status)
            }
        }
        .padding(.vertical, 4)
    }
}
```

### Used in:

```swift
// HomeScreen.swift — Recent activity section
ForEach(recentInvoices) { invoice in
    InvoiceRow(invoice: invoice)
}

// InvoiceListScreen.swift — Full invoice list
ForEach(filteredInvoices) { invoice in
    InvoiceRow(invoice: invoice)
}

// ClientDetailScreen.swift — Invoices for this client
ForEach(clientInvoices) { invoice in
    InvoiceRow(invoice: invoice)
}
```

---

## How a Screen Uses Components

Here's what LoginScreen.swift looks like with reusable components:

```swift
// Screens/Account/LoginScreen.swift
import SwiftUI

struct LoginScreen: View {
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                FormField(                          // ← Reusable
                    label: "Email",
                    text: $email,
                    placeholder: "you@email.com",
                    keyboard: .emailAddress
                )
                
                SecureFormField(                     // ← Reusable
                    label: "Password",
                    text: $password,
                    placeholder: "Enter password"
                )
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
                
                ButtonPrimary(                       // ← Reusable
                    title: "Sign In",
                    isLoading: isLoading,
                    isDisabled: email.isEmpty || password.isEmpty
                ) {
                    doLogin()
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
    
    private func doLogin() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                try await AuthManager.shared.login(email: email, password: password)
                await MainActor.run { isPresented = false }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Login failed"
                    isLoading = false
                }
            }
        }
    }
}
```

**See how clean that is?** The screen is just:
1. State variables at top
2. Components assembled in body
3. One private function for the action

Each screen reads like a recipe: "put a FormField, then another, then a Button."

---

## Where Every Component Gets Used (The Reuse Map)

| Component | Used in screens |
|-----------|----------------|
| `FormField` | Login, Register, BusinessSetup, ClientDetail, BusinessProfile, CreateInvoice |
| `SecureFormField` | Login, Register |
| `ButtonPrimary` | Login, Register, BusinessSetup, TemplatePick, CreateInvoice, ClientDetail |
| `ButtonSecondary` | Welcome (Sign In btn), Paywall (secondary plan) |
| `StatusBadge` | HomeScreen, InvoiceList, InvoiceDetail, InvoiceRow |
| `StatCard` | HomeScreen (3 cards) |
| `InvoiceRow` | HomeScreen, InvoiceList, ClientDetail |
| `ClientRow` | ClientList, ClientPicker |
| `EmptyState` | HomeScreen, InvoiceList, ClientList |
| `SVGView` | InvoiceDetail, InvoiceShare, TemplatePick, TemplateGallery |
| `SheetHeader` | ClientPicker, AddItem |

---

## No Imports Needed Between Your Own Files

In Python you write: `from components.button import ButtonPrimary`
In Swift: **nothing.** All files in the same project/target see each other automatically.

```swift
// LoginScreen.swift — just USE it, no import
struct LoginScreen: View {
    var body: some View {
        FormField(label: "Email", text: $email)    // ← Just works
        ButtonPrimary(title: "Sign In") { ... }     // ← Just works
    }
}
```

The only `import` you ever write is `import SwiftUI` at the top of each file
(like `from django.shortcuts import render` — it's the framework, not your code).

---

## Build Order (Updated)

### Phase 1: Foundation ✅ DONE
- Models.swift, APIClient.swift, AuthManager.swift

### Phase 2: Components (build these FIRST, test in isolation)
| Order | File | Lines | Notes |
|-------|------|-------|-------|
| 2.1 | `FormField.swift` | ~20 | Most reused component |
| 2.2 | `SecureFormField.swift` | ~25 | Password variant |
| 2.3 | `ButtonPrimary.swift` | ~25 | Main action button |
| 2.4 | `ButtonSecondary.swift` | ~20 | Outline variant |
| 2.5 | `StatusBadge.swift` | ~25 | Status colored pill |
| 2.6 | `StatCard.swift` | ~25 | Dashboard number card |
| 2.7 | `InvoiceRow.swift` | ~25 | Invoice list item |
| 2.8 | `ClientRow.swift` | ~20 | Client list item |
| 2.9 | `EmptyState.swift` | ~20 | Empty placeholder |
| 2.10 | `SheetHeader.swift` | ~15 | Sheet drag handle |

**Each component: under 30 lines. You build all 10 in about 1 hour.**

### Phase 3: Account + Router
| Order | File | Notes |
|-------|------|-------|
| 3.1 | `WelcomeScreen.swift` | Uses ButtonPrimary, ButtonSecondary |
| 3.2 | `LoginScreen.swift` | Uses FormField, SecureFormField, ButtonPrimary |
| 3.3 | `RegisterScreen.swift` | Same components as Login |
| 3.4 | `RootView.swift` | Router + MainTabView |
| 3.5 | `InvoicorApp.swift` | Entry point |

**Test: Register → Login → See tab bar**

### Phase 4: Home + Invoices
| Order | File | Notes |
|-------|------|-------|
| 4.1 | `HomeScreen.swift` | Uses StatCard, InvoiceRow, EmptyState |
| 4.2 | `InvoiceListScreen.swift` | Uses InvoiceRow, StatusBadge, EmptyState |
| 4.3 | `SVGView.swift` | WebView wrapper |
| 4.4 | `InvoiceDetailScreen.swift` | Uses SVGView, StatusBadge |

### Phase 5: Create Invoice
| Order | File | Notes |
|-------|------|-------|
| 5.1 | `CreateInvoiceScreen.swift` | Uses FormField, ButtonPrimary |
| 5.2 | `ClientPickerSheet.swift` | Uses ClientRow, SheetHeader |
| 5.3 | `AddItemSheet.swift` | Uses FormField, SheetHeader, ButtonPrimary |

### Phase 6: Clients + Settings
| Order | File | Notes |
|-------|------|-------|
| 6.1 | `ClientListScreen.swift` | Uses ClientRow, EmptyState |
| 6.2 | `ClientDetailScreen.swift` | Uses FormField, ButtonPrimary, InvoiceRow |
| 6.3 | `SettingsScreen.swift` | Settings list |
| 6.4 | `BusinessProfileScreen.swift` | Uses FormField, ButtonPrimary |
| 6.5 | `TemplateGalleryScreen.swift` | Uses SVGView |
| 6.6 | `PaywallScreen.swift` | Plan comparison |

### Phase 7: Onboarding + Polish
| Order | File | Notes |
|-------|------|-------|
| 7.1 | `SplashScreen.swift` | Animated logo |
| 7.2 | `BusinessSetupScreen.swift` | Uses FormField, ButtonPrimary |
| 7.3 | `TemplatePickScreen.swift` | Uses SVGView, ButtonPrimary |
| 7.4 | `Formatters.swift` | Date/currency helpers |

---

## Summary: Your Complete Screen Map

**5 Root tabs:**
1. HomeScreen
2. InvoiceListScreen
3. CreateInvoiceScreen (opens as fullscreen)
4. ClientListScreen
5. SettingsScreen

**11 Sub-screens (pushed or sheeted from root tabs):**
1. LoginScreen (sheet from Welcome)
2. RegisterScreen (sheet from Welcome)
3. InvoiceDetailScreen (push from list/home)
4. InvoiceShareScreen (push from detail)
5. ClientPickerSheet (sheet from Create)
6. AddItemSheet (sheet from Create)
7. ClientDetailScreen (push from client list)
8. BusinessProfileScreen (push from Settings)
9. TemplateGalleryScreen (push from Settings)
10. PaywallScreen (sheet from Settings/anywhere)

**3 Onboarding screens (shown once, before tabs):**
1. SplashScreen
2. BusinessSetupScreen
3. TemplatePickScreen

**1 Pre-auth screen:**
1. WelcomeScreen

**Total: 20 screens, 11 components, all short files.**
