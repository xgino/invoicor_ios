import Foundation

// A custom error enum to handle things gracefully
enum APIError: Error, LocalizedError {
    case badURL
    case serverError(message: String) // 👈 Now holds a string instead of just an Int
    case decodingError
    case unauthorized
    
    // This allows the ViewModel to grab the text easily
    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid server URL."
        case .serverError(let message): return message
        case .decodingError: return "Could not read data from server."
        case .unauthorized: return "Session expired or unauthorized."
        }
    }
}

class APIManager {
    // Creates a "Singleton" so the whole app uses the exact same manager
    static let shared = APIManager()
    private init() {}
    
    // The master function to fetch data from your Django API
    func request<T: Decodable>(endpoint: APIEndpoint, method: String = "GET", body: Data? = nil) async throws -> T {
        
        // 1. Construct the URL using our Environment file
        let fullURLString = "\(APIEnvironment.baseURL)\(endpoint.path)"
        guard let url = URL(string: fullURLString) else {
            throw APIError.badURL
        }
        
        // 2. Build the Request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // TODO: Later, we will inject the User's Auth Token here
        // request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let body = body {
            request.httpBody = body
        }
        
        // 3. Make the Network Call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 4. Check for Django Server Errors
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError(message: "Unknown network error.")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 403 {
                throw APIError.unauthorized
            }
            
            // 👇 NEW: Try to read Django's {"error": "..."} JSON!
            if let errorDict = try? JSONDecoder().decode([String: String].self, from: data),
               let djangoErrorMessage = errorDict["error"] {
                // Throw the exact message Django sent us
                throw APIError.serverError(message: djangoErrorMessage)
            }
            
            // Fallback if Django sends a weird error we didn't expect
            throw APIError.serverError(message: "Server error \(httpResponse.statusCode)")
        }
        
        // 5. Decode the JSON into your pure Swift Models
        do {
            let decodedData = try JSONDecoder().decode(T.self, from: data)
            return decodedData
        } catch {
            print("🚨 Decoding Error: \(error)")
            throw APIError.decodingError
        }
    }
}
