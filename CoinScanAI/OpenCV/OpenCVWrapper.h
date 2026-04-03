#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject

/// Detects and crops the coin region using HoughCircles. Returns a 224×224 image.
+ (nullable UIImage *)detectCoin:(UIImage *)image;

/// Converts image to grayscale.
+ (nullable UIImage *)toGrayscale:(UIImage *)image;

/// Applies CLAHE (Contrast Limited Adaptive Histogram Equalization).
+ (nullable UIImage *)applyCLAHE:(UIImage *)image;

/// Detects edges using Canny algorithm.
+ (nullable UIImage *)detectEdgesCanny:(UIImage *)image;

/// Computes Sobel gradient magnitude.
+ (nullable UIImage *)sobelGradient:(UIImage *)image;

/// Applies Laplacian filter for detail enhancement.
+ (nullable UIImage *)laplacianDetail:(UIImage *)image;

/// Sharpens the image using unsharp mask.
+ (nullable UIImage *)sharpen:(UIImage *)image;

/// Extracts ORB keypoints, contours, and anomaly regions.
/// Returns a dictionary with keys: keypointCount, contourCount, anomalyScore, anomalyRegions.
+ (nullable NSDictionary *)extractFeatures:(UIImage *)image;

@end

NS_ASSUME_NONNULL_END
