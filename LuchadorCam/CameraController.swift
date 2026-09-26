import AVFoundation
import Combine
import Dispatch

// Session setup and the two flags are confined to sessionQueue. Published UI
// state is MainActor-isolated; frames are handled by the serial detectionQueue.
final class CameraController: NSObject, ObservableObject, @unchecked Sendable {
    @MainActor @Published private(set) var message: String? = "カメラを準備しています…"
    @MainActor @Published private(set) var detection: FaceDetection?
    @MainActor @Published private(set) var detectionError: String?

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "local.LuchadorCam.capture")
    private let detectionQueue = DispatchQueue(label: "local.LuchadorCam.face-detection")
    private var faceDetector: FaceDetector?
    private var wantsToRun = false
    private var isConfigured = false

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(sessionFailed(_:)),
            name: AVCaptureSession.runtimeErrorNotification, object: session
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(sessionStopped),
            name: AVCaptureSession.didStopRunningNotification, object: session
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        sessionQueue.async {
            guard !self.wantsToRun else { return }
            self.wantsToRun = true

            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.startAuthorizedSession()
            case .notDetermined:
                self.show("カメラの使用を許可してください。")
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    self.sessionQueue.async {
                        guard self.wantsToRun else { return }
                        if granted {
                            self.startAuthorizedSession()
                        } else {
                            self.showPermissionDenied()
                        }
                    }
                }
            case .denied:
                self.showPermissionDenied()
            case .restricted:
                self.show("このMacではカメラの使用が制限されています。")
            @unknown default:
                self.show("カメラの権限状態を確認できませんでした。")
            }
        }
    }

    func stop() {
        sessionQueue.async {
            self.wantsToRun = false
            if self.session.isRunning {
                self.session.stopRunning()
            }
            NSLog("Capture session stopped (isRunning=%@)", self.session.isRunning ? "true" : "false")
            self.show("カメラを停止しました。")
        }
    }

    private func startAuthorizedSession() {
        guard isConfigured || configureSession() else { return }
        show("カメラを開始しています…")
        session.startRunning()
        NSLog("Capture session start completed (isRunning=%@)", session.isRunning ? "true" : "false")
        show(session.isRunning ? nil : "カメラを開始できませんでした。接続や他のアプリでの使用状況を確認してください。")
    }

    private func configureSession() -> Bool {
        guard let camera = AVCaptureDevice.default(for: .video) else {
            show("利用可能なカメラがありません。カメラを接続してからウィンドウを開き直してください。")
            return false
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            session.beginConfiguration()
            defer { session.commitConfiguration() }

            if session.canSetSessionPreset(.hd1280x720) {
                session.sessionPreset = .hd1280x720
            }
            guard session.canAddInput(input) else {
                show("カメラ入力を追加できませんでした。")
                return false
            }
            session.addInput(input)
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            guard session.canAddOutput(output) else {
                session.removeInput(input)
                show("顔検出用のカメラ出力を追加できませんでした。")
                return false
            }
            session.addOutput(output)
            guard let connection = output.connection(with: .video) else {
                session.removeOutput(output)
                session.removeInput(input)
                show("顔検出用の接続を取得できませんでした。")
                return false
            }
            connection.automaticallyAdjustsVideoMirroring = false
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = false
            }
            if connection.isVideoRotationAngleSupported(0) {
                connection.videoRotationAngle = 0
            }
            guard connection.videoRotationAngle == 0, !connection.isVideoMirrored else {
                session.removeOutput(output)
                session.removeInput(input)
                show("このカメラでは回転0°・非反転の検出入力を設定できませんでした。")
                return false
            }
            let detector = FaceDetector { [weak self] detection, error in
                DispatchQueue.main.async {
                    guard let self, self.message == nil else { return }
                    self.detection = detection
                    self.detectionError = error
                }
            }
            faceDetector = detector
            output.setSampleBufferDelegate(detector, queue: detectionQueue)
            NSLog("VideoDataOutput configured: rotation=%.0f, mirrored=%@, discardsLate=%@",
                  connection.videoRotationAngle, connection.isVideoMirrored ? "true" : "false",
                  output.alwaysDiscardsLateVideoFrames ? "true" : "false")
            isConfigured = true
            return true
        } catch {
            show("カメラを使用できません: \(error.localizedDescription)")
            return false
        }
    }

    private func showPermissionDenied() {
        show("カメラへのアクセスが拒否されています。システム設定 → プライバシーとセキュリティ → カメラでLuchadorCamを許可し、アプリを起動し直してください。")
    }

    private func show(_ text: String?) {
        DispatchQueue.main.async {
            self.message = text
            if text != nil {
                self.detection = nil
                self.detectionError = nil
            }
        }
    }

    @objc private func sessionFailed(_ notification: Notification) {
        let detail = (notification.userInfo?[AVCaptureSessionErrorKey] as? NSError)?.localizedDescription
            ?? "接続や他のアプリでの使用状況を確認してください。"
        sessionQueue.async {
            guard self.wantsToRun else { return }
            self.show("カメラでエラーが発生しました: \(detail)")
        }
    }

    @objc private func sessionStopped() {
        sessionQueue.async {
            guard self.wantsToRun else { return }
            self.show("カメラの映像が停止しました。接続を確認し、アプリを起動し直してください。")
        }
    }
}
