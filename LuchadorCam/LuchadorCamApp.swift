import Foundation
import SwiftUI

@main
struct LuchadorCamApp: App {
    init() {
        _ = MaskImage.image
    }

    var body: some Scene {
        Window("LuchadorCam", id: "main") {
            ContentView()
        }
        .defaultSize(width: 960, height: 540)
    }
}
