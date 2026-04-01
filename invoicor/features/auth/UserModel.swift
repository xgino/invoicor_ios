import Foundation

struct AuthResponse: Codable {
    let email: String?
    let publicId: String?
    let token: String?
    let isPro: Bool?

    // This tells Swift: "Map the JSON 'public_id' to my variable 'publicId'"
    enum CodingKeys: String, CodingKey {
        case email
        case publicId = "public_id"
        case token
        case isPro = "is_pro" // Map Django's is_pro to Swift's isPro
    }
}
