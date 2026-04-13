// =================================================================
// FILE: Core/Models.swift
// =================================================================
// All data models in one file. Matches the Django API responses.
//
// CONVENTIONS:
// - JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase handles
//   snake_case → camelCase automatically. No CodingKeys needed.
// - All models are structs with `let` properties → implicitly Sendable.
// - Equatable + Hashable enable SwiftUI diffing and Set/Dictionary use.
// - Date fields stored as String (Django ISO format), with computed
//   Date? properties where sorting/comparison is needed.

import Foundation

// MARK: - ISO 8601 Date Parsing (Private)

/// Shared date formatters for parsing Django ISO 8601 strings.
/// Supports both microsecond precision ("2025-01-15T10:30:00.123456+00:00")
/// and basic ISO 8601 ("2025-01-15T10:30:00Z").
private enum DateParsing {
    /// Django default: fractional seconds with timezone
    static let microsecondsFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        return f
    }()

    /// Fallback: standard ISO 8601
    static let iso8601Formatter = ISO8601DateFormatter()

    /// Date-only format for issue_date, due_date
    static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Parse a Django datetime string into a Date.
    static func parseDateTime(_ string: String) -> Date? {
        microsecondsFormatter.date(from: string)
            ?? iso8601Formatter.date(from: string)
    }

    /// Parse a date-only string (e.g. "2025-06-15") into a Date.
    static func parseDate(_ string: String) -> Date? {
        dateOnlyFormatter.date(from: string)
    }
}

// MARK: - JSON Value Helper

/// Handles mixed-type values in snapshot dictionaries (strings, bools, numbers, nulls).
/// Used for `sender_snapshot` and `client_snapshot` on invoices.
enum JSONValue: Codable, Equatable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Order matters: Int before Double (42 decodes as both, prefer Int)
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode(Int.self)    { self = .int(v); return }
        if let v = try? container.decode(Double.self)  { self = .double(v); return }
        if let v = try? container.decode(Bool.self)    { self = .bool(v); return }
        if container.decodeNil()                       { self = .null; return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v):    try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v):   try container.encode(v)
        case .null:          try container.encodeNil()
        }
    }

    /// Coerce any variant to a display string. Empty string for null.
    var stringValue: String {
        switch self {
        case .string(let v): return v
        case .int(let v):    return String(v)
        case .double(let v): return String(v)
        case .bool(let v):   return v ? "true" : "false"
        case .null:          return ""
        }
    }
}

// MARK: - Auth Responses

struct LoginResponse: Codable, Sendable {
    let access: String
    let refresh: String
}

struct RegisterResponse: Codable, Sendable {
    let publicId: String
    let email: String
}

// MARK: - User

struct User: Codable, Identifiable, Equatable, Hashable, Sendable {
    let publicId: String
    let email: String
    let tier: String
    let invoicePrefix: String
    let nextInvoiceNumber: Int
    let dateJoined: String

    var id: String { publicId }

    /// Parsed `dateJoined` for sorting or display.
    var dateJoinedDate: Date? { DateParsing.parseDateTime(dateJoined) }
}

// MARK: - /me Endpoint Response

struct MeResponse: Codable, Sendable {
    let user: User
    let subscription: SubscriptionInfo
    let usage: UsageInfo
    let limits: LimitsInfo
}

struct SubscriptionInfo: Codable, Equatable, Sendable {
    let plan: String
    let isActive: Bool
    let isTrial: Bool
    let store: String
    let productId: String
    let expiresAt: String?
    let cancelledAt: String?

    /// Parsed expiration date for countdown or comparison.
    var expiresAtDate: Date? {
        guard let s = expiresAt else { return nil }
        return DateParsing.parseDateTime(s)
    }
}

struct UsageInfo: Codable, Equatable, Sendable {
    let invoicesThisMonth: Int
    let invoicesMonthlyLimit: Int?
    let invoicesTotal: Int
    let invoicesLifetimeLimit: Int?

    /// Whether the user has hit their monthly invoice limit.
    var isMonthlyLimitReached: Bool {
        guard let limit = invoicesMonthlyLimit else { return false }
        return invoicesThisMonth >= limit
    }

    /// Whether the user has hit their lifetime invoice limit.
    var isLifetimeLimitReached: Bool {
        guard let limit = invoicesLifetimeLimit else { return false }
        return invoicesTotal >= limit
    }
}

struct LimitsInfo: Codable, Equatable, Sendable {
    let invoicesPerMonth: Int?
    let invoicesLifetime: Int?
    let itemsPerInvoice: Int?
    let businessProfiles: Int
    let clients: Int?
    let templates: [String]?
}

// MARK: - Business Profile

struct BusinessProfile: Codable, Identifiable, Equatable, Hashable, Sendable {
    let publicId: String
    let isDefault: Bool
    let companyName: String
    let logo: String?
    let website: String
    let defaultCurrency: String
    let defaultLanguage: String
    let defaultTemplate: String
    let defaultTaxRate: String
    let defaultPaymentTerms: String
    let defaultDateFormat: String
    let defaultDueDays: Int
    let email: String
    let phone: String
    let addressLine1: String
    let addressLine2: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
    let taxId: String
    let registrationNumber: String
    let bankName: String
    let iban: String
    let swiftCode: String
    let routingNumber: String
    let accountNumber: String
    let createdAt: String
    let updatedAt: String

    var id: String { publicId }

    /// Display-friendly name, falling back to email or placeholder.
    var displayName: String {
        if !companyName.isEmpty { return companyName }
        if !email.isEmpty { return email }
        return "Unnamed Profile"
    }

    /// Full single-line address for display.
    var formattedAddress: String {
        [addressLine1, addressLine2, city, state, postalCode, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

// MARK: - Client

struct Client: Codable, Identifiable, Equatable, Hashable, Sendable {
    let publicId: String
    let companyName: String
    let contactName: String
    let email: String
    let phone: String
    let addressLine1: String
    let addressLine2: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
    let taxId: String
    let notes: String
    let createdAt: String
    let updatedAt: String

    var id: String { publicId }

    var displayName: String {
        if !companyName.isEmpty { return companyName }
        if !contactName.isEmpty { return contactName }
        if !email.isEmpty { return email }
        return "Unnamed"
    }

    /// Full single-line address for display.
    var formattedAddress: String {
        [addressLine1, addressLine2, city, state, postalCode, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

// MARK: - Invoice

struct Invoice: Codable, Identifiable, Equatable, Hashable, Sendable {
    let publicId: String
    let invoiceNumber: String
    let status: String
    let isLocked: Bool
    let templateSlug: String
    let language: String
    let issueDate: String
    let dueDate: String
    let paymentTerms: String
    let dateFormat: String
    let notes: String
    let senderSnapshot: [String: JSONValue]
    let clientSnapshot: [String: JSONValue]
    let discountType: String
    let discountValue: String
    let discountAmount: String
    let subtotal: String
    let taxRate: String
    let taxInclusive: Bool
    let taxAmount: String
    let total: String
    let currency: String
    let items: [InvoiceItem]
    let createdAt: String
    let updatedAt: String

    var id: String { publicId }

    // MARK: Computed Display Properties

    var clientName: String {
        let company = clientSnapshot["company_name"]?.stringValue ?? ""
        if !company.isEmpty { return company }
        let contact = clientSnapshot["contact_name"]?.stringValue ?? ""
        if !contact.isEmpty { return contact }
        return "No client"
    }

    var totalFormatted: String { "\(currency) \(total)" }

    /// Parsed issue date for sorting.
    var issueDateParsed: Date? { DateParsing.parseDate(issueDate) }

    /// Parsed due date for overdue checks.
    var dueDateParsed: Date? { DateParsing.parseDate(dueDate) }

    /// Parsed creation date for sorting.
    var createdAtDate: Date? { DateParsing.parseDateTime(createdAt) }

    /// Whether the invoice is past due (only meaningful for sent invoices).
    var isPastDue: Bool {
        guard status == "sent",
              let due = dueDateParsed else { return false }
        return Date() > due
    }

    /// Subtotal as Decimal for calculations.
    var subtotalDecimal: Decimal { Decimal(string: subtotal) ?? 0 }

    /// Total as Decimal for calculations.
    var totalDecimal: Decimal { Decimal(string: total) ?? 0 }
}

struct InvoiceItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    let publicId: String
    let name: String
    let description: String
    let quantity: String
    let unitPrice: String
    let amount: String
    let sortOrder: Int

    var id: String { publicId }

    /// Quantity as Decimal for display or recalculation.
    var quantityDecimal: Decimal { Decimal(string: quantity) ?? 0 }

    /// Unit price as Decimal.
    var unitPriceDecimal: Decimal { Decimal(string: unitPrice) ?? 0 }

    /// Line amount as Decimal.
    var amountDecimal: Decimal { Decimal(string: amount) ?? 0 }
}

// MARK: - Paginated Invoice List

struct InvoiceListResponse: Codable, Sendable {
    let results: [Invoice]
    let total: Int
    let limit: Int
    let offset: Int

    /// Whether more pages exist beyond the current one.
    var hasMore: Bool { offset + limit < total }

    /// Offset value for fetching the next page.
    var nextOffset: Int { offset + limit }
}

// MARK: - Product (Saved Items)

struct Product: Codable, Identifiable, Equatable, Hashable, Sendable {
    let publicId: String
    let name: String
    let description: String
    let defaultPrice: String
    let createdAt: String
    let updatedAt: String

    var id: String { publicId }

    /// Default price as Decimal.
    var defaultPriceDecimal: Decimal { Decimal(string: defaultPrice) ?? 0 }
}

// MARK: - Templates

struct InvoiceTemplate: Codable, Identifiable, Equatable, Hashable, Sendable {
    let slug: String
    let name: String
    let filename: String
    let sizeBytes: Int
    let tier: String?       // "free", "starter", "pro", "business" — nil if API hasn't been updated yet

    var id: String { slug }

    /// Display-friendly tier label.
    var tierLabel: String {
        switch tier?.lowercased() {
        case "starter": return "Starter"
        case "pro":     return "Pro"
        case "business":return "Business"
        default:        return ""   // Free templates show no badge
        }
    }
}

// MARK: - Dropdowns

struct Currency: Codable, Identifiable, Hashable, Sendable {
    let code: String
    let name: String
    let symbol: String

    var id: String { code }

    /// e.g. "USD — US Dollar ($)"
    var displayLabel: String { "\(code) — \(name) (\(symbol))" }
}

struct Language: Codable, Identifiable, Hashable, Sendable {
    let code: String
    let name: String

    var id: String { code }
}

// MARK: - Subscription Status Endpoint

struct SubscriptionStatus: Codable, Sendable {
    let subscription: SubscriptionInfo
    let usage: UsageInfo
    let limits: LimitsInfo
}

// MARK: - Feedback

struct FeedbackRequest: Codable, Sendable {
    let type: String
    let subject: String
    let message: String
    let deviceModel: String
    let osVersion: String
    let appVersion: String
    let screen: String
}

struct FeedbackResponse: Codable, Identifiable, Sendable {
    let publicId: String
    let type: String
    let subject: String
    let message: String
    let status: String
    let createdAt: String

    var id: String { publicId }
}

// MARK: - API Error Response

/// Matches Django error payloads. All fields optional because DRF
/// validation errors may return `{"field": ["error"]}` instead of
/// `{"error": "message"}`. The APIClient handles both formats.
struct APIErrorResponse: Codable, Sendable {
    let error: String?
    let code: String?
    let upgradeRequired: Bool?
}
