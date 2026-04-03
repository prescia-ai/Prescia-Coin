import UIKit
import CoreGraphics
import Accelerate

// MARK: - Cloud Feature Extractor
// Extracts privacy-safe mathematical feature vectors from coin images.
// ONLY mathematical descriptors are produced — raw images are never uploaded.

class CloudFeatureExtractor {

    // Number of dimensions in the output feature vector
    static let featureDimensions = 512

    // MARK: - Public API

    /// Extract a 512-dimensional feature vector from a coin image.
    /// The vector encodes edge patterns, texture descriptors, and shape features.
    /// No personally identifiable information is included.
    func extractCloudFeatures(from image: UIImage) -> [Float] {
        guard let cgImage = image.cgImage else {
            return [Float](repeating: 0, count: Self.featureDimensions)
        }

        let sampleSize = 64
        let bytesPerPixel = 4
        let bytesPerRow = sampleSize * bytesPerPixel
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
            return [Float](repeating: 0, count: Self.featureDimensions)
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        var features: [Float] = []

        // 1. Luminance grid (16x16 = 256 values)
        features += luminanceGrid(rawData: rawData, size: sampleSize, gridDivisions: 16)

        // 2. Edge density grid (8x8 = 64 values)
        features += edgeDensityGrid(rawData: rawData, size: sampleSize, gridDivisions: 8)

        // 3. Color channel histograms (3 x 32-bin = 96 values)
        features += colorHistograms(rawData: rawData, size: sampleSize, bins: 32)

        // 4. Texture statistics — mean, variance, skewness, kurtosis per channel (3 x 4 = 12 values)
        features += textureStatistics(rawData: rawData, size: sampleSize)

        // 5. Radial profile — luminance sampled along 21 concentric rings (21 values)
        features += radialProfile(rawData: rawData, size: sampleSize, rings: 21)

        // Pad or truncate to exactly featureDimensions
        if features.count < Self.featureDimensions {
            features += [Float](repeating: 0, count: Self.featureDimensions - features.count)
        } else if features.count > Self.featureDimensions {
            features = Array(features.prefix(Self.featureDimensions))
        }

        return l2Normalize(features)
    }

    // MARK: - Feature Components

    private func luminanceGrid(rawData: [UInt8], size: Int, gridDivisions: Int) -> [Float] {
        let cellSize = size / gridDivisions
        var grid = [Float](repeating: 0, count: gridDivisions * gridDivisions)
        for row in 0..<gridDivisions {
            for col in 0..<gridDivisions {
                var sum: Float = 0
                var count = 0
                for y in (row * cellSize)..<((row + 1) * cellSize) {
                    for x in (col * cellSize)..<((col + 1) * cellSize) {
                        let idx = (y * size + x) * 4
                        let r = Float(rawData[idx])     / 255.0
                        let g = Float(rawData[idx + 1]) / 255.0
                        let b = Float(rawData[idx + 2]) / 255.0
                        sum += 0.299 * r + 0.587 * g + 0.114 * b
                        count += 1
                    }
                }
                grid[row * gridDivisions + col] = count > 0 ? sum / Float(count) : 0
            }
        }
        return grid
    }

    private func edgeDensityGrid(rawData: [UInt8], size: Int, gridDivisions: Int) -> [Float] {
        let cellSize = size / gridDivisions
        var grid = [Float](repeating: 0, count: gridDivisions * gridDivisions)
        for row in 0..<gridDivisions {
            for col in 0..<gridDivisions {
                var edgeCount = 0
                var total = 0
                for y in (row * cellSize)..<((row + 1) * cellSize) {
                    for x in (col * cellSize)..<((col + 1) * cellSize) {
                        guard x < size - 1, y < size - 1 else { continue }
                        let idx  = (y * size + x) * 4
                        let idxR = ((y + 1) * size + x) * 4
                        let idxC = (y * size + x + 1) * 4
                        let lum  = luminance(rawData, idx)
                        let lumR = luminance(rawData, idxR)
                        let lumC = luminance(rawData, idxC)
                        if abs(lum - lumR) > 0.1 || abs(lum - lumC) > 0.1 { edgeCount += 1 }
                        total += 1
                    }
                }
                grid[row * gridDivisions + col] = total > 0 ? Float(edgeCount) / Float(total) : 0
            }
        }
        return grid
    }

    private func colorHistograms(rawData: [UInt8], size: Int, bins: Int) -> [Float] {
        var rHist = [Float](repeating: 0, count: bins)
        var gHist = [Float](repeating: 0, count: bins)
        var bHist = [Float](repeating: 0, count: bins)
        let total = size * size
        for i in 0..<total {
            let idx = i * 4
            let r = Int(rawData[idx]) * bins / 256
            let g = Int(rawData[idx + 1]) * bins / 256
            let b = Int(rawData[idx + 2]) * bins / 256
            rHist[min(r, bins - 1)] += 1
            gHist[min(g, bins - 1)] += 1
            bHist[min(b, bins - 1)] += 1
        }
        let norm = Float(total)
        return rHist.map { $0 / norm } + gHist.map { $0 / norm } + bHist.map { $0 / norm }
    }

    private func textureStatistics(rawData: [UInt8], size: Int) -> [Float] {
        let total = size * size
        var rVals = [Float](); rVals.reserveCapacity(total)
        var gVals = [Float](); gVals.reserveCapacity(total)
        var bVals = [Float](); bVals.reserveCapacity(total)
        for i in 0..<total {
            let idx = i * 4
            rVals.append(Float(rawData[idx])     / 255.0)
            gVals.append(Float(rawData[idx + 1]) / 255.0)
            bVals.append(Float(rawData[idx + 2]) / 255.0)
        }
        return stats(rVals) + stats(gVals) + stats(bVals)
    }

    private func stats(_ values: [Float]) -> [Float] {
        guard !values.isEmpty else { return [0, 0, 0, 0] }
        let n = Float(values.count)
        let mean = values.reduce(0, +) / n
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / n
        let std = sqrt(variance)
        let skewness = std > 0
            ? values.map { pow(($0 - mean) / std, 3) }.reduce(0, +) / n
            : 0
        let kurtosis = std > 0
            ? values.map { pow(($0 - mean) / std, 4) }.reduce(0, +) / n - 3
            : 0
        return [mean, variance, skewness, kurtosis]
    }

    private func radialProfile(rawData: [UInt8], size: Int, rings: Int) -> [Float] {
        let cx = Float(size) / 2.0
        let cy = Float(size) / 2.0
        let maxR = cx
        var ringSum   = [Float](repeating: 0, count: rings)
        var ringCount = [Int](repeating: 0, count: rings)
        for y in 0..<size {
            for x in 0..<size {
                let dx = Float(x) - cx
                let dy = Float(y) - cy
                let r  = sqrt(dx * dx + dy * dy)
                let ring = min(rings - 1, Int(r / maxR * Float(rings)))
                let idx = (y * size + x) * 4
                ringSum[ring]   += luminance(rawData, idx)
                ringCount[ring] += 1
            }
        }
        return zip(ringSum, ringCount).map { $1 > 0 ? $0 / Float($1) : 0 }
    }

    // MARK: - Helpers

    private func luminance(_ data: [UInt8], _ idx: Int) -> Float {
        0.299 * Float(data[idx]) / 255.0
            + 0.587 * Float(data[idx + 1]) / 255.0
            + 0.114 * Float(data[idx + 2]) / 255.0
    }

    private func l2Normalize(_ vector: [Float]) -> [Float] {
        let magnitude = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }
}
