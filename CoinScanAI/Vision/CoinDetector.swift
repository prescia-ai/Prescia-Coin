import UIKit

class CoinDetector {
    private let targetSize = CGSize(width: 224, height: 224)

    func detectCoin(in image: UIImage) -> UIImage? {
        // Try OpenCV HoughCircles first
        let detected = OpenCVWrapper.detectCoin(image)

        if let result = detected {
            return result.resized(to: targetSize)
        }

        // Fallback: center crop to square
        return centerCrop(image: image)
    }

    private func centerCrop(image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let side = min(width, height)

        let cropRect = CGRect(
            x: (width - side) / 2,
            y: (height - side) / 2,
            width: side,
            height: side
        )

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }

        let croppedImage = UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
        return croppedImage.resized(to: targetSize)
    }
}
