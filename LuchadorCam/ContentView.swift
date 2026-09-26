import SwiftUI

struct ContentView: View {
    @StateObject private var cameraController = CameraController()

    var body: some View {
        ZStack {
            CameraPreview(controller: cameraController, detection: cameraController.detection)
            if let message = cameraController.message {
                Text(message)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
            }
            VStack {
                Text("顔: 緑枠 / Vision leftEye: 水色 / rightEye: オレンジ")
                    .font(.caption)
                    .padding(6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                if let error = cameraController.detectionError {
                    Text(error)
                        .padding(6)
                        .background(.regularMaterial)
                }
                Spacer()
            }
            .padding(8)
            .allowsHitTesting(false)
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}
