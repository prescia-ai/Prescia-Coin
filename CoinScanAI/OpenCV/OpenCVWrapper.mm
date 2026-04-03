#import "OpenCVWrapper.h"
#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>

#ifdef __cplusplus
#if __has_include(<opencv2/opencv.hpp>)
#include <opencv2/opencv.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/features2d.hpp>
#define OPENCV_AVAILABLE 1
#else
#define OPENCV_AVAILABLE 0
#endif
#endif

// ---------------------------------------------------------------------------
// MARK: - Helpers
// ---------------------------------------------------------------------------

static UIImage * _Nullable applyCoreImageFilter(UIImage *image, NSString *filterName, NSDictionary * _Nullable params) {
    CIImage *ciImage = [CIImage imageWithCGImage:image.CGImage];
    if (!ciImage) return nil;
    CIFilter *filter = [CIFilter filterWithName:filterName];
    if (!filter) return nil;
    [filter setValue:ciImage forKey:kCIInputImageKey];
    if (params) {
        [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, id val, BOOL *stop) {
            [filter setValue:val forKey:key];
        }];
    }
    CIImage *output = filter.outputImage;
    if (!output) return nil;
    CIContext *ctx = [CIContext context];
    CGImageRef cgOut = [ctx createCGImage:output fromRect:output.extent];
    if (!cgOut) return nil;
    UIImage *result = [UIImage imageWithCGImage:cgOut scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(cgOut);
    return result;
}

// Center-crop helper (no OpenCV needed)
static UIImage * _Nullable centerCrop224(UIImage *image) {
    CGImageRef cg = image.CGImage;
    if (!cg) return nil;
    CGFloat w = CGImageGetWidth(cg);
    CGFloat h = CGImageGetHeight(cg);
    CGFloat side = MIN(w, h);
    CGRect crop = CGRectMake((w - side) / 2.0, (h - side) / 2.0, side, side);
    CGImageRef cropped = CGImageCreateWithImageInRect(cg, crop);
    if (!cropped) return nil;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(224, 224), NO, 1.0);
    [[UIImage imageWithCGImage:cropped] drawInRect:CGRectMake(0, 0, 224, 224)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGImageRelease(cropped);
    return result;
}

// ---------------------------------------------------------------------------
// MARK: - OpenCV Helpers (compiled only when OpenCV is available)
// ---------------------------------------------------------------------------

#if OPENCV_AVAILABLE

static cv::Mat matFromUIImage(UIImage *image) {
    CGImageRef cgImage = image.CGImage;
    size_t width  = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);

    cv::Mat mat((int)height, (int)width, CV_8UC4);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(
        mat.data, width, height, 8, mat.step[0],
        space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault
    );
    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(ctx);
    CGColorSpaceRelease(space);

    cv::Mat result;
    cv::cvtColor(mat, result, cv::COLOR_RGBA2BGR);
    return result;
}

static UIImage *UIImageFromMat(const cv::Mat &mat) {
    cv::Mat rgb;
    if (mat.channels() == 1) {
        cv::cvtColor(mat, rgb, cv::COLOR_GRAY2RGBA);
    } else if (mat.channels() == 3) {
        cv::cvtColor(mat, rgb, cv::COLOR_BGR2RGBA);
    } else {
        rgb = mat.clone();
    }

    NSData *data = [NSData dataWithBytes:rgb.data length:rgb.total() * rgb.elemSize()];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGImageRef cgImage = CGImageCreate(
        rgb.cols, rgb.rows, 8, 32, rgb.cols * 4,
        space,
        kCGBitmapByteOrderDefault | kCGImageAlphaNoneSkipLast,
        provider, NULL, false, kCGRenderingIntentDefault
    );
    UIImage *result = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(space);
    return result;
}

#endif // OPENCV_AVAILABLE

// ---------------------------------------------------------------------------
// MARK: - OpenCVWrapper Implementation
// ---------------------------------------------------------------------------

@implementation OpenCVWrapper

+ (UIImage *)detectCoin:(UIImage *)image {
#if OPENCV_AVAILABLE
    cv::Mat src = matFromUIImage(image);
    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_BGR2GRAY);
    cv::GaussianBlur(gray, gray, cv::Size(9, 9), 2, 2);

    std::vector<cv::Vec3f> circles;
    cv::HoughCircles(
        gray, circles, cv::HOUGH_GRADIENT,
        1,          // dp
        gray.rows / 8, // minDist
        200,        // param1 (Canny high threshold)
        50,         // param2 (accumulator threshold)
        gray.rows / 8, // minRadius
        gray.rows / 2  // maxRadius
    );

    if (!circles.empty()) {
        cv::Vec3f c = circles[0];
        int cx = cvRound(c[0]);
        int cy = cvRound(c[1]);
        int r  = cvRound(c[2]);

        int x = std::max(0, cx - r);
        int y = std::max(0, cy - r);
        int w = std::min(src.cols - x, 2 * r);
        int h = std::min(src.rows - y, 2 * r);

        cv::Rect roi(x, y, w, h);
        cv::Mat cropped = src(roi);
        cv::Mat resized;
        cv::resize(cropped, resized, cv::Size(224, 224));
        return UIImageFromMat(resized);
    }

    // Fallback: center crop
    cv::Mat resized;
    int side = std::min(src.cols, src.rows);
    int ox = (src.cols - side) / 2;
    int oy = (src.rows - side) / 2;
    cv::Mat cropped = src(cv::Rect(ox, oy, side, side));
    cv::resize(cropped, resized, cv::Size(224, 224));
    return UIImageFromMat(resized);

#else
    return centerCrop224(image);
#endif
}

+ (UIImage *)toGrayscale:(UIImage *)image {
#if OPENCV_AVAILABLE
    cv::Mat src = matFromUIImage(image);
    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_BGR2GRAY);
    return UIImageFromMat(gray);
#else
    return applyCoreImageFilter(image, @"CIPhotoEffectNoir", nil);
#endif
}

+ (UIImage *)applyCLAHE:(UIImage *)image {
#if OPENCV_AVAILABLE
    cv::Mat src = matFromUIImage(image);
    cv::Mat lab;
    cv::cvtColor(src, lab, cv::COLOR_BGR2Lab);

    std::vector<cv::Mat> channels;
    cv::split(lab, channels);

    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(2.0, cv::Size(8, 8));
    clahe->apply(channels[0], channels[0]);

    cv::merge(channels, lab);
    cv::Mat result;
    cv::cvtColor(lab, result, cv::COLOR_Lab2BGR);
    return UIImageFromMat(result);
#else
    return applyCoreImageFilter(image, @"CIVibrance", @{kCIInputAmountKey: @(1.0)});
#endif
}

+ (UIImage *)detectEdgesCanny:(UIImage *)image {
#if OPENCV_AVAILABLE
    cv::Mat src = matFromUIImage(image);
    cv::Mat gray, edges;
    cv::cvtColor(src, gray, cv::COLOR_BGR2GRAY);
    cv::GaussianBlur(gray, gray, cv::Size(5, 5), 1.5);
    cv::Canny(gray, edges, 50, 150);
    return UIImageFromMat(edges);
#else
    return applyCoreImageFilter(image, @"CIEdges", @{kCIInputIntensityKey: @(5.0)});
#endif
}

+ (UIImage *)sobelGradient:(UIImage *)image {
#if OPENCV_AVAILABLE
    cv::Mat src = matFromUIImage(image);
    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_BGR2GRAY);

    cv::Mat gx, gy;
    cv::Sobel(gray, gx, CV_16S, 1, 0, 3);
    cv::Sobel(gray, gy, CV_16S, 0, 1, 3);

    cv::Mat absGx, absGy, grad;
    cv::convertScaleAbs(gx, absGx);
    cv::convertScaleAbs(gy, absGy);
    cv::addWeighted(absGx, 0.5, absGy, 0.5, 0, grad);
    return UIImageFromMat(grad);
#else
    return applyCoreImageFilter(image, @"CIEdgeWork", @{kCIInputRadiusKey: @(3.0)});
#endif
}

+ (UIImage *)laplacianDetail:(UIImage *)image {
#if OPENCV_AVAILABLE
    cv::Mat src = matFromUIImage(image);
    cv::Mat gray, lap, lapAbs;
    cv::cvtColor(src, gray, cv::COLOR_BGR2GRAY);
    cv::Laplacian(gray, lap, CV_16S, 3);
    cv::convertScaleAbs(lap, lapAbs);
    return UIImageFromMat(lapAbs);
#else
    return applyCoreImageFilter(image, @"CISharpenLuminance", @{kCIInputSharpnessKey: @(2.0)});
#endif
}

+ (UIImage *)sharpen:(UIImage *)image {
#if OPENCV_AVAILABLE
    cv::Mat src = matFromUIImage(image);
    cv::Mat blurred, result;
    cv::GaussianBlur(src, blurred, cv::Size(0, 0), 3);
    cv::addWeighted(src, 1.5, blurred, -0.5, 0, result);
    return UIImageFromMat(result);
#else
    return applyCoreImageFilter(image, @"CIUnsharpMask", @{
        kCIInputRadiusKey: @(2.5),
        kCIInputIntensityKey: @(0.5)
    });
#endif
}

+ (NSDictionary *)extractFeatures:(UIImage *)image {
#if OPENCV_AVAILABLE
    cv::Mat src = matFromUIImage(image);
    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_BGR2GRAY);

    // --- ORB Keypoints ---
    cv::Ptr<cv::ORB> orb = cv::ORB::create(500);
    std::vector<cv::KeyPoint> keypoints;
    cv::Mat descriptors;
    orb->detectAndCompute(gray, cv::noArray(), keypoints, descriptors);

    // --- Canny + Contours ---
    cv::Mat edges;
    cv::Canny(gray, edges, 50, 150);
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(edges, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    // --- Edge Density per Grid Block ---
    int gridSize = 4;
    int blockW = gray.cols / gridSize;
    int blockH = gray.rows / gridSize;

    NSMutableArray<NSDictionary *> *anomalyRegions = [NSMutableArray array];
    float totalEdge = 0.0f;
    std::vector<float> densities;

    for (int gy = 0; gy < gridSize; gy++) {
        for (int gx = 0; gx < gridSize; gx++) {
            cv::Rect roi(gx * blockW, gy * blockH, blockW, blockH);
            cv::Mat block = edges(roi);
            int edgeCount = cv::countNonZero(block);
            float density = (float)edgeCount / (float)(blockW * blockH);
            totalEdge += density;
            densities.push_back(density);
        }
    }

    float mean = totalEdge / (float)densities.size();
    float variance = 0;
    for (float d : densities) { variance += (d - mean) * (d - mean); }
    variance /= (float)densities.size();
    float stdDev = std::sqrt(variance);

    float maxAnomaly = 0.0f;

    for (int i = 0; i < (int)densities.size(); i++) {
        float density = densities[i];
        float deviation = std::abs(density - mean);
        if (stdDev > 0.001f && deviation > 2.0f * stdDev && density > 0.05f) {
            int gx = i % gridSize;
            int gy = i / gridSize;
            float confidence = std::min(1.0f, deviation / (stdDev * 4.0f));
            std::string typeLabel = (density > mean + 2 * stdDev)
                ? "High Edge Density"
                : "Possible Double Die";
            [anomalyRegions addObject:@{
                @"x": @(gx * blockW),
                @"y": @(gy * blockH),
                @"w": @(blockW),
                @"h": @(blockH),
                @"type": [NSString stringWithUTF8String:typeLabel.c_str()],
                @"confidence": @(confidence)
            }];
            maxAnomaly = std::max(maxAnomaly, confidence);
        }
    }

    float anomalyScore = std::min(1.0f, maxAnomaly + mean * 0.3f);

    return @{
        @"keypointCount":  @((int)keypoints.size()),
        @"contourCount":   @((int)contours.size()),
        @"anomalyScore":   @(anomalyScore),
        @"anomalyRegions": anomalyRegions
    };

#else
    // Fallback: return minimal feature data without OpenCV
    return @{
        @"keypointCount":  @(0),
        @"contourCount":   @(0),
        @"anomalyScore":   @(0.0f),
        @"anomalyRegions": @[]
    };
#endif
}

@end
