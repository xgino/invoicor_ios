import Foundation

enum APIEndpoint {
    // Auth
    case login
    case register
    case tokenRefresh
    
    // Business Profiles
    case businessProfiles
    case businessProfileDetail(id: String)
    
    // Clients
    case clients
    case clientDetail(id: String)
    
    // Invoices
    case invoices
    case invoiceDetail(id: String)
    case renderInvoice(id: String)
    
    // Templates
    case templates
    case templateRaw(slug: String)
    case templateFields(slug: String)
    
    // Dropdowns
    case currencies
    case languages
    
    // This variable automatically generates the correct string path
    var path: String {
        switch self {
        case .login: return "/accounts/login/"
        case .register: return "/accounts/register/"
        case .tokenRefresh: return "/accounts/token/refresh/"
            
        case .businessProfiles: return "/accounts/business-profiles/"
        case .businessProfileDetail(let id): return "/accounts/business-profiles/\(id)/"
            
        case .clients: return "/accounts/clients/"
        case .clientDetail(let id): return "/accounts/clients/\(id)/"
            
        case .invoices: return "/invoices/"
        case .invoiceDetail(let id): return "/invoices/\(id)/"
        case .renderInvoice(let id): return "/invoices/\(id)/render/"
            
        case .templates: return "/invoices/templates/"
        case .templateRaw(let slug): return "/invoices/templates/\(slug)/"
        case .templateFields(let slug): return "/invoices/templates/\(slug)/fields/"
            
        case .currencies: return "/invoices/currencies/"
        case .languages: return "/invoices/languages/"
        }
    }
}
