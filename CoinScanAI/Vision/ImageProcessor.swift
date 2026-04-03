import UIKit

struct ProcessedImage {
    let type: ProcessingType
    let image: UIImage
}

enum ProcessingType: String, CaseIterable, Codable {
    case original   = "Original"
    case edges      = "Edges"
    case contrast   = "Contrast"
    case gradient   = "Gradient"
    case sharpened  = "Sharpened"
    case laplacian  = "Laplacian"
}

class ImageProcessor {

    func toGrayscale(image: UIImage) -> UIImage {
        return OpenCVWrapper.toGrayscale(image) ?? fallbackGrayscale(image)
    }

    func applyCLAHE(image: UIImage) -> UIImage {
        return OpenCVWrapper.applyCLAHE(image) ?? fallbackCLAHE(image)
    }

    func detectEdgesCanny(image: UIImage) -> UIImage {
        return OpenCVWrapper.detectEdgesCanny(image) ?? fallbackEdges(image)
    }

    func sobelGradient(image: UIImage) -> UIImage {
        return OpenCVWrapper.sobelGradient(image) ?? fallbackSobel(image)
    }

    func laplacianDetail(image: UIImage) -> UIImage {
        return OpenCVWrapper.laplacianDetail(image) ?? fallbackLaplacian(image)
    }

    func sharpen(image: UIImage) -> UIImage {
        return OpenCVWrapper.sharpen(image) ?? fallbackSharpen(image)
    }

    func generateAllVariants(image: UIImage) -> [ProcessedImage] {
        return [
            ProcessedImage(type: .original,  image: image),
            ProcessedImage(type: .edges,      image: detectEdgesCanny(image: image)),
            ProcessedImage(type: .contrast,   image: applyCLAHE(image: image)),
            ProcessedImage(type: .gradient,   image: sobelGradient(image: image)),
            ProcessedImage(type: .sharpened,  image: sharpen(image: image)),
            ProcessedImage(type: .laplacian,  image: laplacianDetail(image: image))
        ]
    }

    // MARK: - CoreImage Fallbacks

    private func applyCIFilter(_ image: UIImage, filter: CIFilter?) -> UIImage {
        guard let filter = filter,
              let ciImage = CIImage(image: image) else { return image }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let output = filter.outputImage else { return image }
        let context = CIContext()
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func fallbackGrayscale(_ image: UIImage) -> UIImage {
        let filter = CIFilter(name: "CIPhotoEffectNoir")
        return applyCIFilter(image, filter: filter)
    }

    private func fallbackCLAHE(_ image: UIImage) -> UIImage {
        guard let filter = CIFilter(name: "CIVibrance") else { return image }
        filter.setValue(1.0, forKey: kCIInputAmountKey)
        return applyCIFilter(image, filter: filter)
    }

    private func fallbackEdges(_ image: UIImage) -> UIImage {
        guard let filter = CIFilter(name: "CIEdges") else { return image }
        filter.setValue(5.0, forKey: kCIInputIntensityKey)
        return applyCIFilter(image, filter: filter)
    }

    private func fallbackSobel(_ image: UIImage) -> UIImage {
        guard let filter = CIFilter(name: "CIEdgeWork") else { return image }
        filter.setValue(3.0, forKey: kCIInputRadiusKey)
        return applyCIFilter(image, filter: filter)
    }

    private func fallbackLaplacian(_ image: UIImage) -> UIImage {
        guard let filter = CIFilter(name: "CISharpenLuminance") else { return image }
        filter.setValue(2.0, forKey: kCIInputSharpnessKey)
        return applyCIFilter(image, filter: filter)
    }

    private func fallbackSharpen(_ image: UIImage) -> UIImage {
        guard let filter = CIFilter(name: "CIUnsharpMask") else { return image }
        filter.setValue(2.5, forKey: kCIInputRadiusKey)
        filter.setValue(0.5, forKey: kCIInputIntensityKey)
        return applyCIFilter(image, filter: filter)
    }
}
