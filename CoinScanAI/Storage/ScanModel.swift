import Foundation
import CoreGraphics

struct ScanResult: Identifiable, Codable {
    let id: String
    let date: Date
    let anomalyScore: Float
    let detectedIssues: [DetectedIssue]
    let aiPrediction: String
    let aiConfidence: Float
    let imagePaths: [String: String]

    // MARK: - Hybrid Anomaly Detection Fields (optional for backward compatibility)

    /// Anomaly type from AI detection: "counterfeit", "damage", "manufacturing_error",
    /// "wear", "alteration", or "normal"
    let anomalyType: String?
    /// Severity of the detected anomaly (0.0 – 1.0)
    let anomalySeverity: Float?
    /// Human-readable condition grade, e.g. "Fine", "Uncirculated"
    let conditionGrade: String?
    /// Numeric condition score (0 – 100)
    let conditionScore: Float?
    /// Which detection pipeline produced the result: "traditional", "ai", or "hybrid"
    let detectionMethod: String?
    /// Confidence reported by the AI anomaly model (0.0 – 1.0)
    let aiAnomalyConfidence: Float?
}

struct DetectedIssue: Codable {
    let type: String
    let confidence: Float
    let rect: CodableRect
}

struct CodableRect: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    init(_ rect: CGRect) {
        x      = rect.origin.x
        y      = rect.origin.y
        width  = rect.size.width
        height = rect.size.height
    }
}
