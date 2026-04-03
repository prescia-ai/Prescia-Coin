# Prescia-Coin (CoinScan AI)

An iOS application that uses computer vision and AI to identify and classify coins through camera scanning.

## Features

- **📸 Coin Scanning**: Capture coin images using your device's camera
- **🎯 Automatic Detection**: Uses OpenCV's HoughCircles algorithm to detect and isolate coins from background
- **🧠 AI Classification**: Machine learning model to identify coin types with confidence scores
- **📊 Anomaly Detection**: Visual indicators for potential counterfeit or damaged coins
- **💾 Scan History**: Save and review previous scans with timestamps
- **🔄 Image Processing**: Generates multiple image variants for enhanced analysis
- **✨ Feature Extraction**: Analyzes coin characteristics including edges, circles, and texture patterns

## Supported Coins

- Penny (Lincoln)
- Nickel (Jefferson)
- Dime (Roosevelt)
- Quarter (Washington)
- Half Dollar (Kennedy)
- Dollar (Sacagawea)
- Morgan Dollar
- Peace Dollar
- Wheat Penny
- Indian Head Penny

## Tech Stack

- **Language**: Swift
- **Framework**: SwiftUI
- **Computer Vision**: OpenCV (for coin detection using Hough Circle Transform)
- **Image Processing**: Core Graphics, Accelerate framework
- **AI Model**: TensorFlow Lite (ready to integrate)
- **Storage**: Local file system with JSON persistence

## Architecture

```
CoinScanAI/
├── App/              # SwiftUI views and app entry point
│   ├── CoinScanAIApp.swift
│   ├── ContentView.swift
│   ├── CameraView.swift
│   └── ResultView.swift
├── Vision/           # Computer vision and image processing
│   ├── CoinDetector.swift
│   ├── ImageProcessor.swift
│   └── FeatureExtractor.swift
├── AI/               # Machine learning model runner
│   └── ModelRunner.swift
├── OpenCV/           # OpenCV wrapper for coin detection
├── Storage/          # Data persistence layer
└── Utils/            # Helper utilities
```

## How It Works

1. **Capture**: User takes a photo of a coin using the camera interface
2. **Detection**: OpenCV detects the coin in the image and crops it
3. **Processing**: Image is resized to 224x224 and processed into multiple variants
4. **Feature Extraction**: Extracts visual features (edges, circles, texture)
5. **Classification**: AI model predicts the coin type with confidence score
6. **Anomaly Analysis**: Calculates anomaly score based on extracted features
7. **Storage**: Saves results with images and metadata for future reference

## Requirements

- iOS 14.0+
- Xcode 13.0+
- Swift 5.5+
- OpenCV framework

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/prescia-ai/Prescia-Coin.git
   ```

2. Open the project in Xcode:
   ```bash
   cd Prescia-Coin
   open CoinScanAI.xcodeproj
   ```

3. Build and run on your iOS device or simulator

## ML Model Integration

The app is designed to work with TensorFlow Lite models. To add a trained model:

1. Add your `CoinClassifier.tflite` model to the project bundle
2. The `ModelRunner` will automatically detect and use the model
3. Without a model, the app uses a mock classifier for demonstration

## Anomaly Detection

The app calculates an anomaly score based on:
- Edge detection confidence
- Circle detection quality
- Texture analysis
- Feature consistency

Visual indicators:
- 🟢 Green - Low (0-30%): Normal coin
- 🟠 Orange - Medium (30-60%): Possible irregularities
- 🔴 Red - High (60-100%): High anomaly detected

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is available under the MIT License.

## Author

Prescia AI