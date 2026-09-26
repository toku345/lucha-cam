import Foundation

enum FaceGeometry {
    // Vision landmarks are face-local, normalized, with a lower-left origin.
    static func eyeCenter(_ points: [CGPoint], in face: CGRect) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let sum = points.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
        }
        let count = CGFloat(points.count)
        return CGPoint(
            x: face.minX + sum.x / count * face.width,
            y: face.minY + sum.y / count * face.height
        )
    }

    // Only for .up Vision input from an unrotated, unmirrored capture buffer.
    // Capture-device / metadata coordinates use the unrotated image's top-left.
    static func capturePoint(fromVision point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: 1 - point.y)
    }

    static func metadataRect(fromVision rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: 1 - rect.maxY, width: rect.width, height: rect.height)
    }
}
