import SwiftUI
import AVFoundation

struct CameraView: View {
    let completion: (UIImage?) -> Void

    @StateObject private var coordinator = CameraCoordinator()
    @State private var permissionDenied = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if permissionDenied {
                VStack(spacing: 16) {
                    Image(systemName: "camera.slash.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    Text("Camera Access Denied")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Please enable camera access in Settings.")
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    Button("Close") { completion(nil) }
                        .buttonStyle(.bordered)
                        .tint(.white)
                }
                .padding()
            } else {
                CameraPreviewView(session: coordinator.session)
                    .ignoresSafeArea()

                VStack {
                    HStack {
                        Button(action: { completion(nil) }) {
                            Image(systemName: "xmark")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding()

                    Spacer()

                    // Viewfinder guide
                    let viewfinderSize: CGFloat = 240
                    RoundedRectangle(cornerRadius: viewfinderSize / 2)
                        .stroke(Color.white.opacity(0.7), lineWidth: 2)
                        .frame(width: viewfinderSize, height: viewfinderSize)

                    Spacer()

                    Button(action: { coordinator.capturePhoto() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 72, height: 72)
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 84, height: 84)
                        }
                    }
                    .padding(.bottom, 40)
                    .disabled(!coordinator.isReady)
                    .opacity(coordinator.isReady ? 1.0 : 0.5)
                }
            }
        }
        .onAppear {
            checkPermissions()
        }
        .onReceive(coordinator.$capturedImage) { image in
            guard let image = image else { return }
            completion(image)
        }
    }

    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            coordinator.startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        coordinator.startSession()
                    } else {
                        permissionDenied = true
                    }
                }
            }
        default:
            permissionDenied = true
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }

    class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
        }
    }
}

// MARK: - Camera Coordinator

class CameraCoordinator: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    @Published var capturedImage: UIImage?
    @Published var isReady = false

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(input)

            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }

            self.session.commitConfiguration()
            self.session.startRunning()

            DispatchQueue.main.async { self.isReady = true }
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        DispatchQueue.main.async { self.capturedImage = image }
    }

    deinit {
        if session.isRunning { session.stopRunning() }
    }
}
