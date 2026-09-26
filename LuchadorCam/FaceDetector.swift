import AVFoundation
import ImageIO
import Vision

struct FaceDetection: Sendable {
    // Full-image normalized coordinates in Vision's lower-left-origin space.
    let boundingBox: CGRect
    let leftEye: CGPoint?
    let rightEye: CGPoint?
}

// The request and mutable fields are used only by the serial delegate queue.
final class FaceDetector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let request = VNDetectFaceLandmarksRequest()
    private let onResult: @Sendable (FaceDetection?, String?) -> Void
    private var lastStarted: TimeInterval = -.infinity
    private var loggedFrame = false
    private var loggedFace = false
    private var lastError: String?

    init(onResult: @escaping @Sendable (FaceDetection?, String?) -> Void) {
        self.onResult = onResult
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastStarted >= 0.1 else { return }
        lastStarted = now

        autoreleasepool {
            guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                fail("カメラの画像バッファを取得できませんでした。")
                return
            }
            let attachment = CMGetAttachment(
                sampleBuffer, key: kCGImagePropertyOrientation, attachmentModeOut: nil
            ) as? NSNumber
            if !loggedFrame {
                NSLog(
                    "Vision input: %ldx%ld, rotation=%.0f, mirrored=%@, orientationAttachment=%@",
                    CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer),
                    connection.videoRotationAngle, connection.isVideoMirrored ? "true" : "false",
                    attachment?.stringValue ?? "none"
                )
                loggedFrame = true
            }
            guard connection.videoRotationAngle == 0, !connection.isVideoMirrored,
                  attachment == nil || attachment?.uint32Value == CGImagePropertyOrientation.up.rawValue else {
                fail("検出入力の向きが想定と異なります。回転0°・非反転の入力が必要です。")
                return
            }

            do {
                // The connection is explicitly normalized and checked above;
                // .up is not a general assumption about arbitrary cameras.
                let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
                try handler.perform([request])
                lastError = nil
                guard let face = request.results?.max(by: {
                    $0.boundingBox.width * $0.boundingBox.height
                        < $1.boundingBox.width * $1.boundingBox.height
                }) else {
                    onResult(nil, nil)
                    return
                }
                let result = FaceDetection(
                    boundingBox: face.boundingBox,
                    leftEye: FaceGeometry.eyeCenter(
                        face.landmarks?.leftEye?.normalizedPoints ?? [], in: face.boundingBox
                    ),
                    rightEye: FaceGeometry.eyeCenter(
                        face.landmarks?.rightEye?.normalizedPoints ?? [], in: face.boundingBox
                    )
                )
                if !loggedFace {
                    NSLog("Vision detected a face (leftEye=%@, rightEye=%@)",
                          result.leftEye == nil ? "false" : "true", result.rightEye == nil ? "false" : "true")
                    loggedFace = true
                }
                onResult(result, nil)
            } catch {
                fail("顔検出に失敗しました: \(error.localizedDescription)")
            }
        }
    }

    private func fail(_ message: String) {
        if lastError != message {
            NSLog("%@", message)
            lastError = message
        }
        onResult(nil, message)
    }
}
