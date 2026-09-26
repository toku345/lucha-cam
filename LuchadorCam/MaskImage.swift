import Foundation
import ImageIO

@MainActor
enum MaskImage {
    static let image: CGImage? = {
        guard let url = Bundle.main.url(forResource: "mask", withExtension: "png") else {
            NSLog("ERROR: mask.png is missing from the app bundle")
            return nil
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(
                  source,
                  0,
                  [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
              ) else {
            NSLog("ERROR: mask.png could not be decoded")
            return nil
        }

        NSLog("mask.png decoded: %ldx%ld", image.width, image.height)
        return image
    }()

}
