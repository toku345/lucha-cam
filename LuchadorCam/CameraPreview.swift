import AppKit
import AVFoundation
import SwiftUI

struct CameraPreview: NSViewRepresentable {
    let controller: CameraController
    let detection: FaceDetection?

    func makeNSView(context: Context) -> CameraPreviewView {
        CameraPreviewView(controller: controller)
    }

    func updateNSView(_ nsView: CameraPreviewView, context: Context) {
        nsView.updateDetection(detection)
    }

    static func dismantleNSView(_ nsView: CameraPreviewView, coordinator: ()) {
        nsView.controller.stop()
    }
}

@MainActor
final class CameraPreviewView: NSView {
    // Preview conversion APIs return top-left-origin display coordinates.
    // Let AppKit flip the backing-layer geometry to match, including shape paths.
    override var isFlipped: Bool { true }

    let controller: CameraController
    private let previewLayer: AVCaptureVideoPreviewLayer
    private let maskLayer = CALayer()
    private let maskImage = MaskImage.image
    private let faceLayer = CAShapeLayer()
    private let leftEyeLayer = CAShapeLayer()
    private let rightEyeLayer = CAShapeLayer()
    private var detection: FaceDetection?
    private var loggedPreview = false

    init(controller: CameraController) {
        self.controller = controller
        previewLayer = AVCaptureVideoPreviewLayer(session: controller.session)
        super.init(frame: .zero)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = true
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
        maskLayer.isHidden = true
        maskLayer.anchorPoint = .zero
        maskLayer.position = .zero
        if let maskImage {
            maskLayer.contents = maskImage
            maskLayer.bounds = CGRect(x: 0, y: 0, width: maskImage.width, height: maskImage.height)
        }
        previewLayer.addSublayer(maskLayer)
        faceLayer.strokeColor = NSColor.systemGreen.cgColor
        faceLayer.fillColor = nil
        faceLayer.lineWidth = 2
        leftEyeLayer.fillColor = NSColor.systemCyan.cgColor
        rightEyeLayer.fillColor = NSColor.systemOrange.cgColor
        for debugLayer in [faceLayer, leftEyeLayer, rightEyeLayer] {
            previewLayer.addSublayer(debugLayer)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        drawDetection()
        CATransaction.commit()
    }

    func updateDetection(_ detection: FaceDetection?) {
        self.detection = detection
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        drawDetection()
        CATransaction.commit()
    }

    private func drawDetection() {
        for debugLayer in [faceLayer, leftEyeLayer, rightEyeLayer] {
            debugLayer.frame = previewLayer.bounds
        }
        maskLayer.isHidden = true
        guard let detection, let connection = previewLayer.connection else {
            faceLayer.path = nil
            leftEyeLayer.path = nil
            rightEyeLayer.path = nil
            return
        }
        if !loggedPreview {
            NSLog("Preview mapping: rotation=%.0f, mirrored=%@, gravity=%@",
                  connection.videoRotationAngle, connection.isVideoMirrored ? "true" : "false",
                  previewLayer.videoGravity.rawValue)
            NSLog("Overlay geometry: viewFlipped=%@, rootFlipped=%@, shapeContentsFlipped=%@",
                  isFlipped ? "true" : "false", layer?.isGeometryFlipped == true ? "true" : "false",
                  faceLayer.contentsAreFlipped() ? "true" : "false")
            loggedPreview = true
        }
        // Conversion APIs account for preview rotation, mirroring and aspect-fill.
        // Paths share previewLayer's local coordinates; no extra Y/mirror transform.
        let rect = previewLayer.layerRectConverted(
            fromMetadataOutputRect: FaceGeometry.metadataRect(fromVision: detection.boundingBox)
        )
        faceLayer.path = CGPath(rect: rect, transform: nil)
        let leftEye = previewPoint(detection.leftEye)
        let rightEye = previewPoint(detection.rightEye)
        leftEyeLayer.path = eyePath(leftEye)
        rightEyeLayer.path = eyePath(rightEye)
        if let maskImage, let leftEye, let rightEye,
           let transform = MaskGeometry.transform(
               imageSize: CGSize(width: maskImage.width, height: maskImage.height),
               leftEye: leftEye, rightEye: rightEye
           ) {
            // Zero anchor/position lets the affine transform map PNG pixels directly.
            maskLayer.setAffineTransform(transform)
            maskLayer.isHidden = false
        }
    }

    private func previewPoint(_ point: CGPoint?) -> CGPoint? {
        guard let point else { return nil }
        return previewLayer.layerPointConverted(
            fromCaptureDevicePoint: FaceGeometry.capturePoint(fromVision: point)
        )
    }

    private func eyePath(_ center: CGPoint?) -> CGPath? {
        guard let center else { return nil }
        return CGPath(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10), transform: nil)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
        guard let window else {
            controller.stop()
            return
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification, object: window
        )
        controller.start()
    }

    @objc private func windowWillClose() {
        controller.stop()
    }
}
