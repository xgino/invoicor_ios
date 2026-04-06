// ALL data models in one file. Matches the Django API responses.
//
// We use JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase so
// Swift auto-converts snake_case JSON keys to camelCase properties.
// This means NO CodingKeys needed — just name your properties in
// camelCase and the decoder handles the mapping automatically.
//
// Example: JSON "invoice_number" → Swift "invoiceNumber"
import Foundation
// MARK: - JSON Value Helper
/// Handles mixed-type values in snapshot dictionaries (strings, bools, numbers, nulls).
/// Usage: invoice.clientSnapshot["company_name"]?.stringValue
enum JSONValue: Codable, Equatable {
case string(String)
case int(Int)
case double(Double)
case bool(Bool)
case null
init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if let v = try? c.decode(String.self) { self = .string(v); return }
    if let v = try? c.decode(Int.self) { self = .int(v); return }
    if let v = try? c.decode(Double.self) { self = .double(v); return }
    if let v = try? c.decode(Bool.self) { self = .bool(v); return }
    if c.decodeNil() { self = .null; return }
    self = .null
}

func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .string(let v): try c.encode(v)
    case .int(let v): try c.encode(v)
    case .double(let v): try c.encode(v)
    case .bool(let v): try c.encode(v)
    case .null: try c.encodeNil()
    }
}

/// Extract any value as a String for display purposes
var stringValue: String {
    switch self {
    case .string(let v): return v
    case .int(let v): return String(v)
    case .double(let v): return String(v)
    case .bool(let v): return v ? "true" : "false"
    case .null: return ""
    }
}
}
// MARK: - Auth Responses
struct LoginResponse: Codable {
let access: String
let refresh: String
}
struct RegisterResponse: Codable {
let publicId: String
let email: String
}
// MARK: - User
struct User: Codable, Identifiable {
let publicId: String
let email: String
let tier: String
let invoicePrefix: String
let nextInvoiceNumber: Int
let dateJoined: String
var id: String { publicId }
}
// MARK: - /me Endpoint Response
struct MeResponse: Codable {
let user: User
let subscription: SubscriptionInfo
let usage: UsageInfo
let limits: LimitsInfo
}
struct SubscriptionInfo: Codable {
let plan: String
let isActive: Bool
let isTrial: Bool?
let isLifetime: Bool?
let store: String?
let expiresAt: String?
let cancelledAt: String?
}
struct UsageInfo: Codable {
let invoicesUsed: Int
let invoicesLimit: Int?
let limitType: String
}
struct LimitsInfo: Codable {
let invoicesPerMonth: Int?
let invoicesLifetime: Int?
let businessProfiles: Int
let maxItemsPerInvoice: Int?
let premiumTemplates: Bool
let analytics: Bool
}
// MARK: - Business Profile
struct BusinessProfile: Codable, Identifiable {
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
let paypalEmail: String
let venmoHandle: String
let createdAt: String
let updatedAt: String
var id: String { publicId }
}
// MARK: - Client
struct Client: Codable, Identifiable {
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
}
// MARK: - Invoice
struct Invoice: Codable, Identifiable {
let publicId: String
let invoiceNumber: String
let status: String
let isLocked: Bool
let templateSlug: String
let language: String
let issueDate: String
let dueDate: String
let paymentTerms: String
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
    
/// Extract client name from the frozen snapshot
var clientName: String {
    let company = clientSnapshot["company_name"]?.stringValue ?? ""
    if !company.isEmpty { return company }
    let contact = clientSnapshot["contact_name"]?.stringValue ?? ""
    if !contact.isEmpty { return contact }
    return "No client"
}

var totalFormatted: String { "\(currency) \(total)" }
}
struct InvoiceItem: Codable, Identifiable {
let publicId: String
let description: String
let quantity: String
let unitPrice: String
let amount: String
let sortOrder: Int
var id: String { publicId }
}
// MARK: - Product (Saved Items)
struct Product: Codable, Identifiable {
    let publicId: String
    let name: String
    let description: String
    let defaultPrice: String
    let createdAt: String
    var id: String { publicId }
}
// MARK: - Templates
struct InvoiceTemplate: Codable, Identifiable {
let slug: String
let name: String
let filename: String
let sizeBytes: Int
var id: String { slug }
}
// MARK: - Dropdowns
struct Currency: Codable, Identifiable, Hashable {
let code: String
let name: String
let symbol: String
var id: String { code }
}
struct Language: Codable, Identifiable, Hashable {
let code: String
let name: String
var id: String { code }
}
// MARK: - Subscription Status Endpoint
struct SubscriptionStatus: Codable {
let subscription: SubscriptionInfo
let usage: UsageInfo
let limits: LimitsInfo
}
// MARK: - API Error Response
struct APIErrorResponse: Codable {
let error: String
let code: String?
let upgradeRequired: Bool?
}
// 
