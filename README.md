# Prescia-Coin (CoinScan AI)

An iOS application that uses computer vision and AI to identify and classify coins through camera scanning.

## Features

- **📸 Coin Scanning**: Capture coin images using your device's camera
- **🎯 Automatic Detection**: Uses OpenCV's HoughCircles algorithm to detect and isolate coins from background
- **🧠 AI Classification**: Machine learning model to identify coin types with confidence scores
- **🔬 Hybrid Anomaly Detection**: Combines traditional CV with AI deep learning for accurate flaw detection
- **💾 Scan History**: Save and review previous scans with timestamps
- **🔄 Image Processing**: Generates multiple image variants for enhanced analysis
- **✨ Feature Extraction**: Analyzes coin characteristics including edges, circles, and texture patterns
- **🏅 Condition Grading**: AI-powered condition assessment on a standard numismatic scale

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
- **Multi-Task Learning**: Coin classification + anomaly detection + condition grading
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
│   └── FeatureExtractor.swift    # Hybrid CV + AI extraction
├── AI/               # Machine learning model runners
│   ├── ModelRunner.swift         # Multi-task classification model
│   └── AnomalyDetector.swift     # Dedicated anomaly detection module
├── OpenCV/           # OpenCV wrapper for coin detection
├── Storage/          # Data persistence layer
└── Utils/            # Helper utilities
```

## How It Works

1. **Capture**: User takes a photo of a coin using the camera interface
2. **Detection**: OpenCV detects the coin in the image and crops it
3. **Processing**: Image is resized to 224x224 and processed into multiple variants
4. **Feature Extraction**: Traditional CV extracts edges, circles, and texture features
5. **AI Anomaly Analysis**: `AnomalyDetector` runs deep analysis on the image
6. **Hybrid Fusion**: Traditional CV score and AI severity are combined with confidence weighting
7. **Classification**: AI model predicts coin type, anomaly type, and condition grade
8. **Storage**: Saves all results with images and metadata for future reference

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

---

## Hybrid Anomaly Detection System

CoinScan AI uses a cutting-edge hybrid approach combining traditional computer vision with deep learning for superior anomaly detection.

### Detection Methods

#### 1. Traditional Computer Vision (Fast Baseline)
- Edge density analysis across 4x4 grid
- Statistical deviation detection
- Pattern recognition for common defects
- Real-time performance
- Works offline without ML model

#### 2. AI-Powered Deep Analysis
- Autoencoder-based anomaly detection
- Multi-task neural network:
  - Coin type classification
  - Anomaly detection
  - Condition grading
- Context-aware analysis (understands normal wear vs. damage)
- Detects subtle counterfeits and manufacturing errors

#### 3. Hybrid Fusion
- Traditional CV quickly identifies suspicious regions
- AI performs deep analysis on the full image
- Confidence-weighted combination of both scores
- Best of both worlds: speed + accuracy

### Detected Anomaly Types

- **Counterfeits** 🚫: Wrong metal composition, fake patina, incorrect dimensions
- **Manufacturing Errors** ⚠️: Double die, off-center strikes, clipped planchets (often valuable!)
- **Damage** 💔: Scratches, dents, corrosion, cleaning marks
- **Wear** 🕐: Normal circulation wear vs. problematic damage
- **Alterations** ✏️: Post-mint modifications or cleaning

### Condition Grading

The AI assesses coin condition on a standard numismatic scale:

| Grade | Description |
|-------|-------------|
| Poor | Heavily worn, barely identifiable |
| Fair | Heavily worn but major features visible |
| Good | Design outline clear |
| Very Good | Design clear, some details visible |
| Fine | Moderate to considerable wear |
| Very Fine | Light to medium wear on high points |
| Extremely Fine | Light wear on highest points only |
| About Uncirculated | Slight wear on high points |
| Uncirculated | No trace of wear |

### Visual Indicators

- 🚫 **Red Alert**: Possible counterfeit detected
- ⚠️ **Orange Warning**: Manufacturing error or significant damage
- 💎 **Blue Info**: High-grade coin detected
- 🟢 **Green Check**: Normal coin in good condition
- ⭐ **Gold Star**: Exceptional condition (high grade)

---

## Anomaly Detection (Legacy)

The traditional CV anomaly score is still available and calculated based on:
- Edge detection confidence
- Circle detection quality
- Texture analysis
- Feature consistency

Visual score indicators:
- 🟢 Green (0-30%): Normal coin
- 🟠 Orange (30-60%): Possible irregularities
- 🔴 Red (60-100%): High anomaly detected

---

## AI Model Architecture

### Multi-Task Learning Network

The app supports TensorFlow Lite models with multiple output heads:

1. **Classification Head**: Identifies coin type (10 classes)
2. **Anomaly Head**: Detects irregularities and flaw types (6 classes)
3. **Grading Head**: Assesses coin condition (9 grades)

### Model Integration

To use a custom trained model:

1. Train a multi-task model with three outputs:
   - Classification: softmax over coin types
   - Anomaly: sigmoid for anomaly detection + softmax for anomaly type
   - Grading: softmax over condition grades

2. Convert to TensorFlow Lite format

3. Add models to the project bundle:
   - `CoinClassifier.tflite` (classification only)
   - `AnomalyDetector.tflite` (anomaly detection)
   - Or use a single multi-task model: `CoinAnalyzer.tflite`

4. The app automatically detects and uses available models

### Fallback Behavior

Without ML models, the app provides:
- Mock classification based on image pixel statistics
- Traditional CV-based anomaly detection
- Basic condition estimation derived from anomaly scores

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is available under the MIT License.

## Author

Prescia AI