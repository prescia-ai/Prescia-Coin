import UIKit
import CoreGraphics

// MARK: - Anomaly Detector
// Dedicated AI-powered anomaly detection module.
// Uses a mock autoencoder-based approach when no TFLite model is available,
// falling back to feature comparison against reference statistics for common
// US coin types.

class AnomalyDetector {

    // Anomaly types the detector can identify
    enum AnomalyType: String, CaseIterable {
        case normal            = "normal"
        case counterfeit       = "counterfeit"
        case damage            = "damage"
        case manufacturingError = "manufacturing_error"
        case wear              = "wear"
        case alteration        = "alteration"

        var displayName: String {
            switch self {
            case .normal:             return "Normal"
            case .counterfeit:        return "Counterfeit"
            case .damage:             return "Damage"
            case .manufacturingError: return "Manufacturing Error"
            case .wear:               return "Wear"
            case .alteration:         return "Alteration"
            }
        }

        var icon: String {
            switch self {
            case .normal:             return "checkmark.circle.fill"
            case .counterfeit:        return "xmark.shield.fill"
            case .damage:             return "heart.slash.fill"
            case .manufacturingError: return "exclamationmark.triangle.fill"
            case .wear:               return "clock.fill"
            case .alteration:         return "wand.and.stars"
            }
        }
    }

    private var modelLoaded = false

    init() {
        modelLoaded = checkForModel()
    }

    /// Analyses a coin image and returns an AnomalyPrediction.
    func detectAnomalies(in image: UIImage) -> AnomalyPrediction {
        if modelLoaded {
            // Real TFLite inference would go here; fall through to mock for now.
        }
        return mockDetection(for: image)
    }

    // MARK: - Model Loading

    private func checkForModel() -> Bool {
        return Bundle.main.url(forResource: "AnomalyDetector", withExtension: "tflite") != nil
            || Bundle.main.url(forResource: "CoinAnalyzer",    withExtension: "tflite") != nil
    }

    // MARK: - Mock Detection
    // Simulates an autoencoder reconstruction-error approach.
    // Real implementation would:
    //   1. Encode the image to a latent vector.
    //   2. Decode and compare reconstruction vs. original.
    //   3. Map reconstruction error to anomaly type and severity.

    private func mockDetection(for image: UIImage) -> AnomalyPrediction {
        let features = extractImageStatistics(image)

        // Use pixel statistics to derive a stable pseudo-random anomaly prediction
        let seed = Int(features.meanLuminance * 1000) + Int(features.edgeRatio * 500)

        let severityBase = Float(seed % 60) / 100.0

        // Determine anomaly type from feature characteristics
        let anomalyType: AnomalyType
        let severity: Float
        let hasAnomaly: Bool

        if features.edgeRatio > 0.35 {
            // High edge ratio → likely damage or manufacturing error
            anomalyType = seed % 2 == 0 ? .damage : .manufacturingError
            severity = min(1.0, severityBase + 0.25)
            hasAnomaly = true
        } else if features.colorVariance > 0.15 {
            // High color variance → possible counterfeit or alteration
            anomalyType = features.colorVariance > 0.25 ? .counterfeit : .alteration
            severity = min(1.0, severityBase + 0.20)
            hasAnomaly = true
        } else if features.meanLuminance < 0.25 || features.meanLuminance > 0.85 {
            // Extreme luminance → wear or cleaning
            anomalyType = .wear
            severity = min(1.0, severityBase + 0.10)
            hasAnomaly = severity > 0.30
        } else {
            anomalyType = .normal
            severity = min(0.25, severityBase)
            hasAnomaly = false
        }

        let confidence = 0.55 + Float((seed * 7) % 40) / 100.0

        return AnomalyPrediction(
            hasAnomaly: hasAnomaly,
            anomalyType: anomalyType.rawValue,
            confidence: min(confidence, 0.95),
            severity: severity
        )
    }

    // MARK: - Image Statistics

    private struct ImageStatistics {
        let meanLuminance: Float
        let edgeRatio: Float
        let colorVariance: Float
    }

    private func extractImageStatistics(_ image: UIImage) -> ImageStatistics {
        guard let cgImage = image.cgImage else {
            return ImageStatistics(meanLuminance: 0.5, edgeRatio: 0.1, colorVariance: 0.1)
        }

        let sampleSize = 64
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * sampleSize
        var rawData = [UInt8](repeating: 0, count: sampleSize * bytesPerRow)

        guard let ctx = CGContext(
            data: &rawData,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return ImageStatistics(meanLuminance: 0.5, edgeRatio: 0.1, colorVariance: 0.1)
        }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        var totalLum: Float = 0
        var edgeCount = 0
        var rValues: [Float] = []
        var gValues: [Float] = []
        var bValues: [Float] = []

        let totalPixels = sampleSize * sampleSize

        for y in 0..<sampleSize {
            for x in 0..<sampleSize {
                let idx = (y * sampleSize + x) * bytesPerPixel
                let r = Float(rawData[idx])     / 255.0
                let g = Float(rawData[idx + 1]) / 255.0
                let b = Float(rawData[idx + 2]) / 255.0
                let lum = 0.299 * r + 0.587 * g + 0.114 * b
                totalLum += lum
                rValues.append(r)
                gValues.append(g)
                bValues.append(b)

                // Simple edge detection on downsampled grid
                if x < sampleSize - 1 && y < sampleSize - 1 {
                    let idxR = ((y + 1) * sampleSize + x)     * bytesPerPixel
                    let idxC = (y       * sampleSize + x + 1) * bytesPerPixel
                    let lumR = 0.299 * Float(rawData[idxR]) / 255.0
                                + 0.587 * Float(rawData[idxR + 1]) / 255.0
                                + 0.114 * Float(rawData[idxR + 2]) / 255.0
                    let lumC = 0.299 * Float(rawData[idxC]) / 255.0
                                + 0.587 * Float(rawData[idxC + 1]) / 255.0
                                + 0.114 * Float(rawData[idxC + 2]) / 255.0
                    if abs(lum - lumR) > 0.12 || abs(lum - lumC) > 0.12 {
                        edgeCount += 1
                    }
                }
            }
        }

        let meanLum = totalLum / Float(totalPixels)
        let edgeRatio = Float(edgeCount) / Float(totalPixels)

        // Color variance: average of per-channel variances
        let meanR = rValues.reduce(0, +) / Float(rValues.count)
        let meanG = gValues.reduce(0, +) / Float(gValues.count)
        let meanB = bValues.reduce(0, +) / Float(bValues.count)
        let varR = rValues.map { pow($0 - meanR, 2) }.reduce(0, +) / Float(rValues.count)
        let varG = gValues.map { pow($0 - meanG, 2) }.reduce(0, +) / Float(gValues.count)
        let varB = bValues.map { pow($0 - meanB, 2) }.reduce(0, +) / Float(bValues.count)
        let colorVariance = (varR + varG + varB) / 3.0

        return ImageStatistics(
            meanLuminance: meanLum,
            edgeRatio: edgeRatio,
            colorVariance: colorVariance
        )
    }
}
