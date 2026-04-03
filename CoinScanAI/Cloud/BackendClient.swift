import Foundation

// MARK: - Backend Response Models

struct VerificationResult: Codable {
    let matchCount: Int
    let confidence: Float
    /// "verified", "suspicious", or "unknown"
    let status: String
    let similarCoins: [SimilarCoin]
}

struct SimilarCoin: Codable {
    let coinType: String
    let similarity: Float
    let verificationCount: Int
}

// MARK: - Backend Client

/// Communicates with a self-hosted coin-verification backend.
/// All network calls are async and time-out after `timeoutInterval` seconds.
/// The client degrades gracefully when the backend is unreachable.
class BackendClient {

    // MARK: - Configuration

    var baseURL: String {
        UserDefaults.standard.string(forKey: "backendURL") ?? "http://localhost:3000/api"
    }

    static let shared = BackendClient()

    private let timeoutInterval: TimeInterval = 10
    private let cacheExpiry: TimeInterval = 300  // 5-minute cache

    private var referenceCountsCache: [String: Int]?
    private var referenceCountsCacheTime: Date?

    private var session: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval
        return URLSession(configuration: config)
    }

    // MARK: - API Endpoints

    /// Verify a coin against the community database using its feature vector.
    func verifyCoins(features: [Float], coinType: String) async -> VerificationResult? {
        guard let url = URL(string: baseURL + "/verify") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "features": features,
            "coinType": coinType,
            "deviceId": anonymousDeviceID()
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = data

        do {
            let (responseData, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return nil }
            return try JSONDecoder().decode(VerificationResult.self, from: responseData)
        } catch {
            return nil
        }
    }

    /// Contribute an anonymised feature vector to the community database.
    @discardableResult
    func contribute(features: [Float], coinType: String, verified: Bool) async -> Bool {
        guard let url = URL(string: baseURL + "/contribute") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "features": features,
            "coinType": coinType,
            "verified": verified,
            "deviceId": anonymousDeviceID()
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return false }
        request.httpBody = data

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
        } catch {
            return false
        }
    }

    /// Retrieve the number of reference samples per coin type from the backend.
    func getReferenceCounts() async -> [String: Int] {
        // Return cached value if still fresh
        if let cached = referenceCountsCache,
           let cacheTime = referenceCountsCacheTime,
           Date().timeIntervalSince(cacheTime) < cacheExpiry {
            return cached
        }

        guard let url = URL(string: baseURL + "/reference-counts") else { return [:] }
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let counts = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
            referenceCountsCache     = counts
            referenceCountsCacheTime = Date()
            return counts
        } catch {
            return [:]
        }
    }

    /// Check whether the backend is reachable.
    func isBackendReachable() async -> Bool {
        guard let url = URL(string: baseURL + "/health") else { return false }
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
        } catch {
            return false
        }
    }

    // MARK: - Privacy

    /// Returns a stable, anonymous identifier derived from the device's vendor ID.
    /// No personal information is embedded.
    private func anonymousDeviceID() -> String {
        if let cached = UserDefaults.standard.string(forKey: "anonymousDeviceID") {
            return cached
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: "anonymousDeviceID")
        return newID
    }
}
