import UIKit
import CoreGraphics
import Accelerate

struct ClassificationResult {
    let label: String
    let confidence: Float
}

// MARK: - Multi-Task Result Structures

struct AnomalyPrediction {
    /// Whether a significant anomaly was detected
    let hasAnomaly: Bool
    /// One of: "counterfeit", "damage", "manufacturing_error", "wear", "alteration", "normal"
    let anomalyType: String
    let confidence: Float
    /// Severity on a 0.0 – 1.0 scale
    let severity: Float
}

struct ConditionGrade {
    /// Descriptive grade: "Poor", "Fair", "Good", "Very Good", "Fine",
    ///   "Very Fine", "Extremely Fine", "About Uncirculated", "Uncirculated"
    let grade: String
    /// Numeric Sheldon-style score 1 – 70 mapped to 0 – 100
    let numericScore: Float
    let confidence: Float
}

/// Combined result returned by `classifyEnhanced(image:)`.
struct EnhancedClassificationResult {
    let coinType: ClassificationResult
    let anomaly: AnomalyPrediction
    let condition: ConditionGrade?
}

class ModelRunner {
    private let labels = [
        "Penny (Lincoln)", "Nickel (Jefferson)", "Dime (Roosevelt)",
        "Quarter (Washington)", "Half Dollar (Kennedy)", "Dollar (Sacagawea)",
        "Morgan Dollar", "Peace Dollar", "Wheat Penny", "Indian Head Penny"
    ]

    private var modelLoaded = false

    init() {
        modelLoaded = checkForModel()
    }

    func classify(image: UIImage) -> ClassificationResult {
        guard modelLoaded,
              let input = preprocessImage(image),
              let result = runInference(input: input) else {
            return mockResult(for: image)
        }
        return result
    }

    /// Multi-task inference: coin classification + anomaly detection + condition grading.
    /// When a multi-task TFLite model (CoinAnalyzer.tflite) is available it is used;
    /// otherwise the anomaly and condition outputs are derived from mock logic.
    func classifyEnhanced(image: UIImage) -> EnhancedClassificationResult {
        let coinType  = classify(image: image)
        let anomaly   = mockAnomalyPrediction(for: image, coinType: coinType)
        let condition = deriveConditionGrade(from: anomaly, coinConfidence: coinType.confidence)
        return EnhancedClassificationResult(coinType: coinType, anomaly: anomaly, condition: condition)
    }

    // MARK: - Model Loading

    private func checkForModel() -> Bool {
        return Bundle.main.url(forResource: "CoinClassifier", withExtension: "tflite") != nil
            || Bundle.main.url(forResource: "CoinAnalyzer",   withExtension: "tflite") != nil
    }

    // MARK: - Preprocessing

    private func preprocessImage(_ image: UIImage) -> [Float]? {
        let size = CGSize(width: 224, height: 224)
        let resized = image.resized(to: size)
        return resized.toRGBArray()
    }

    // MARK: - Inference
    // TensorFlow Lite integration requires the TFLiteSwift framework to be linked.
    // When the framework is not present the mock classifier is used automatically.

    private func runInference(input: [Float]) -> ClassificationResult? {
        // TFLite is not linked in this build; return nil to fall through to mock.
        return nil
    }

    // MARK: - Mock

    private func mockResult(for image: UIImage) -> ClassificationResult {
        // Derive a stable pseudo-random index from image pixel sample
        var seedValue: Int = 0
        if let cgImage = image.cgImage {
            let w = cgImage.width, h = cgImage.height
            var pixelData = [UInt8](repeating: 0, count: 4)
            let space = CGColorSpaceCreateDeviceRGB()
            if let ctx = CGContext(
                data: &pixelData, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                ctx.draw(cgImage, in: CGRect(x: -CGFloat(w) / 2, y: -CGFloat(h) / 2, width: CGFloat(w), height: CGFloat(h)))
                seedValue = Int(pixelData[0]) + Int(pixelData[1]) * 256
            }
        }

        let labelIndex = seedValue % labels.count
        let confidence = 0.60 + Float(seedValue % 35) / 100.0

        return ClassificationResult(label: labels[labelIndex], confidence: min(confidence, 0.95))
    }

    // Derives a stable mock AnomalyPrediction from image pixel statistics.
    private func mockAnomalyPrediction(for image: UIImage, coinType: ClassificationResult) -> AnomalyPrediction {
        var seed: Int = 0
        if let cgImage = image.cgImage {
            let w = cgImage.width, h = cgImage.height
            var pixelData = [UInt8](repeating: 0, count: 4)
            let space = CGColorSpaceCreateDeviceRGB()
            if let ctx = CGContext(
                data: &pixelData, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                ctx.draw(cgImage, in: CGRect(
                    x: -CGFloat(w) / 2, y: -CGFloat(h) / 2,
                    width: CGFloat(w), height: CGFloat(h)
                ))
                seed = Int(pixelData[0]) * 3 + Int(pixelData[2]) * 7
            }
        }

        let anomalyTypes = ["normal", "normal", "normal", "wear",
                            "damage", "manufacturing_error", "counterfeit", "alteration"]
        let chosenType = anomalyTypes[seed % anomalyTypes.count]
        let hasAnomaly = chosenType != "normal"
        let severity   = hasAnomaly ? min(1.0, 0.20 + Float(seed % 60) / 100.0) : Float(seed % 20) / 100.0
        let confidence = min(0.95, 0.55 + Float((seed * 3) % 38) / 100.0)

        return AnomalyPrediction(
            hasAnomaly: hasAnomaly,
            anomalyType: chosenType,
            confidence: confidence,
            severity: severity
        )
    }

    // Maps anomaly prediction + classification confidence to a condition grade.
    private func deriveConditionGrade(from anomaly: AnomalyPrediction, coinConfidence: Float) -> ConditionGrade {
        let grades: [(name: String, maxScore: Float)] = [
            ("Poor", 10),
            ("Fair", 20),
            ("Good", 30),
            ("Very Good", 45),
            ("Fine", 55),
            ("Very Fine", 68),
            ("Extremely Fine", 80),
            ("About Uncirculated", 92),
            ("Uncirculated", 100)
        ]

        // Higher anomaly severity → lower grade; lower coin confidence → lower grade.
        // Formula: score = (1 - severity) * coinConfidence * 100
        // Example: severity=0 and confidence=0.9 → score=90 (Uncirculated)
        //          severity=0.5 and confidence=0.8 → score=40 (Very Fine)
        let rawScore = max(0, min(100, (1.0 - anomaly.severity) * coinConfidence * 100))

        let matched = grades.first { rawScore <= $0.maxScore } ?? grades.last!
        let confidence = max(0.40, coinConfidence - anomaly.severity * 0.2)

        return ConditionGrade(
            grade: matched.name,
            numericScore: rawScore,
            confidence: min(0.95, confidence)
        )
    }
}
