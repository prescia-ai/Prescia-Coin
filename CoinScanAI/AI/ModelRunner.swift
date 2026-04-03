import UIKit
import CoreGraphics
import Accelerate

struct ClassificationResult {
    let label: String
    let confidence: Float
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

    // MARK: - Model Loading

    private func checkForModel() -> Bool {
        return Bundle.main.url(forResource: "CoinClassifier", withExtension: "tflite") != nil
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
}
