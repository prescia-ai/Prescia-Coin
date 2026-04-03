import UIKit
import CoreGraphics
import ImageIO
import Accelerate

extension UIImage {

    // MARK: - Resize

    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Normalize (pixel values to [0, 1])

    func normalized() -> UIImage {
        guard let cgImage = self.cgImage else { return self }
        let width  = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow   = bytesPerPixel * width
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        let space = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: &rawData,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return self }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Normalize to 0–255 range based on min/max (per-image normalization)
        var minVal: UInt8 = 255
        var maxVal: UInt8 = 0
        for i in stride(from: 0, to: rawData.count, by: bytesPerPixel) {
            let r = rawData[i], g = rawData[i+1], b = rawData[i+2]
            let lum = max(r, max(g, b))
            let dark = min(r, min(g, b))
            maxVal = max(maxVal, lum)
            minVal = min(minVal, dark)
        }

        let range = Float(maxVal - minVal)
        guard range > 0 else { return self }

        for i in stride(from: 0, to: rawData.count, by: bytesPerPixel) {
            rawData[i]   = UInt8(Float(rawData[i]   - minVal) / range * 255)
            rawData[i+1] = UInt8(Float(rawData[i+1] - minVal) / range * 255)
            rawData[i+2] = UInt8(Float(rawData[i+2] - minVal) / range * 255)
        }

        guard let outCtx = CGContext(
            data: &rawData,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let outCG = outCtx.makeImage() else { return self }

        return UIImage(cgImage: outCG, scale: self.scale, orientation: self.imageOrientation)
    }

    // MARK: - Pixel Buffer

    func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        let scaled = self.resized(to: CGSize(width: width, height: height))
        guard let cgImage = scaled.cgImage else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }

    // MARK: - RGB Float Array

    func toRGBArray() -> [Float]? {
        let targetSize = CGSize(width: 224, height: 224)
        let scaled = self.resized(to: targetSize)
        guard let cgImage = scaled.cgImage else { return nil }

        let width  = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow   = bytesPerPixel * width
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        let space = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: &rawData,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Convert to float array [R, G, B, R, G, B, ...] normalized to [-1, 1]
        // 127.5 = 255 / 2, maps [0, 255] → [-1, 1] as required by MobileNet-style models
        let normalizationFactor: Float = 127.5
        var floats = [Float](repeating: 0, count: width * height * 3)
        var floatIdx = 0
        for i in stride(from: 0, to: rawData.count, by: bytesPerPixel) {
            floats[floatIdx]     = (Float(rawData[i])   / normalizationFactor) - 1.0
            floats[floatIdx + 1] = (Float(rawData[i+1]) / normalizationFactor) - 1.0
            floats[floatIdx + 2] = (Float(rawData[i+2]) / normalizationFactor) - 1.0
            floatIdx += 3
        }

        return floats
    }

    // MARK: - CGImage Orientation

    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}
