import Foundation

enum APIEnvironment {
    static var baseURL: String {
        // Safely grabs the URL from your plist
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String else {
            fatalError("🚨 BASE_URL is missing from Info.plist")
        }
        return urlString
    }
}
