import UIKit
import CoreGraphics

struct ExtractionResult {
    let keypointCount: Int
    let contourCount: Int
    let anomalyScore: Float
    let anomalyRegions: [AnomalyRegion]
}

struct AnomalyRegion {
    let rect: CGRect
    let type: String
    let confidence: Float
}

class FeatureExtractor {

    func extract(from image: UIImage) -> ExtractionResult {
        // Try OpenCV feature extraction
        if let dict = OpenCVWrapper.extractFeatures(image) as? [String: Any] {
            return parseOpenCVResult(dict, imageSize: image.size)
        }

        // Fallback: rule-based analysis using pixel data
        return fallbackExtraction(from: image)
    }

    // MARK: - Parse OpenCV Result

    private func parseOpenCVResult(_ dict: [String: Any], imageSize: CGSize) -> ExtractionResult {
        let keypointCount = dict["keypointCount"] as? Int ?? 0
        let contourCount  = dict["contourCount"]  as? Int ?? 0
        let rawScore      = dict["anomalyScore"]  as? Float ?? 0

        var regions: [AnomalyRegion] = []
        if let rawRegions = dict["anomalyRegions"] as? [[String: Any]] {
            for r in rawRegions {
                let x = r["x"] as? Double ?? 0
                let y = r["y"] as? Double ?? 0
                let w = r["w"] as? Double ?? 0
                let h = r["h"] as? Double ?? 0
                let type = r["type"] as? String ?? "Unknown"
                let conf = r["confidence"] as? Float ?? 0.5
                regions.append(AnomalyRegion(
                    rect: CGRect(x: x, y: y, width: w, height: h),
                    type: type,
                    confidence: conf
                ))
            }
        }

        return ExtractionResult(
            keypointCount: keypointCount,
            contourCount: contourCount,
            anomalyScore: min(1.0, rawScore),
            anomalyRegions: regions
        )
    }

    // MARK: - Fallback Pixel-Based Analysis

    private func fallbackExtraction(from image: UIImage) -> ExtractionResult {
        guard let cgImage = image.cgImage else {
            return ExtractionResult(keypointCount: 0, contourCount: 0, anomalyScore: 0, anomalyRegions: [])
        }

        let width  = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let ctx = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return ExtractionResult(keypointCount: 0, contourCount: 0, anomalyScore: 0, anomalyRegions: [])
        }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Analyze edge density in a grid of 4x4 blocks
        let gridSize = 4
        let blockW = width / gridSize
        let blockH = height / gridSize
        // 30/255 ≈ 12% luminance difference — sensitive enough to catch subtle die
        // doubling and cracks while rejecting JPEG compression noise.
        let edgeDetectionThreshold: Float = 30

        var edgeDensities: [Float] = []

        for gy in 0..<gridSize {
            for gx in 0..<gridSize {
                var edgeCount = 0
                let startX = gx * blockW
                let startY = gy * blockH

                for y in startY..<(startY + blockH - 1) {
                    for x in startX..<(startX + blockW - 1) {
                        let idx = (y * width + x) * bytesPerPixel
                        let idxR = ((y + 1) * width + x) * bytesPerPixel
                        let idxC = (y * width + (x + 1)) * bytesPerPixel

                        let lum: (Int) -> Float = { i in
                            let r = Float(rawData[i])
                            let g = Float(rawData[i + 1])
                            let b = Float(rawData[i + 2])
                            return 0.299 * r + 0.587 * g + 0.114 * b
                        }

                        let current = lum(idx)
                        let below   = lum(idxR)
                        let right   = lum(idxC)

                        if abs(current - below) > edgeDetectionThreshold || abs(current - right) > edgeDetectionThreshold {
                            edgeCount += 1
                        }
                    }
                }

                let total = blockW * blockH
                edgeDensities.append(Float(edgeCount) / Float(total))
            }
        }

        // Anomaly detection: blocks with unusually high or low edge density
        let mean = edgeDensities.reduce(0, +) / Float(edgeDensities.count)
        let variance = edgeDensities.map { pow($0 - mean, 2) }.reduce(0, +) / Float(edgeDensities.count)
        let stdDev = sqrt(variance)

        var anomalyRegions: [AnomalyRegion] = []
        var anomalyScore: Float = 0

        // deviationMultiplier: blocks must be > 2 std deviations from mean to flag as anomaly
        // minimumDensityThreshold: ignore near-empty blocks (< 5% edge pixels)
        let deviationMultiplier: Float = 2.0
        let minimumDensityThreshold: Float = 0.05

        for (i, density) in edgeDensities.enumerated() {
            let deviation = abs(density - mean)
            if stdDev > 0 && deviation > deviationMultiplier * stdDev && density > minimumDensityThreshold {
                let gx = i % gridSize
                let gy = i / gridSize
                let rect = CGRect(
                    x: Double(gx * blockW),
                    y: Double(gy * blockH),
                    width: Double(blockW),
                    height: Double(blockH)
                )
                let confidence = min(1.0, Float(deviation / (stdDev + 0.001)) / 4.0)
                let typeLabel = density > mean + 2 * stdDev ? "High Edge Density" : "Possible Double Die"
                anomalyRegions.append(AnomalyRegion(rect: rect, type: typeLabel, confidence: confidence))
                anomalyScore = max(anomalyScore, confidence)
            }
        }

        // Estimate keypoints and contours from overall edge density
        let keypointEstimate = Int(mean * Float(width * height) / 10.0)
        let contourEstimate  = anomalyRegions.count * 3 + Int(mean * 20)

        return ExtractionResult(
            keypointCount: keypointEstimate,
            contourCount: contourEstimate,
            anomalyScore: min(1.0, anomalyScore + mean * 0.3),
            anomalyRegions: anomalyRegions
        )
    }
}
