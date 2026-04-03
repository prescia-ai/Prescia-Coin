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
