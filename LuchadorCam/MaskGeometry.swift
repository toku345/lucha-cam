import Foundation

// PNG anchors use normalized coordinates measured from the image's top-left.
// Names correspond to the Vision landmarks verified in Step 3.
enum MaskGeometry {
    static let leftEyeAnchor = CGPoint(x: 0.290, y: 0.428)
    static let rightEyeAnchor = CGPoint(x: 0.708, y: 0.428)

    static func transform(imageSize: CGSize, leftEye: CGPoint, rightEye: CGPoint) -> CGAffineTransform? {
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }
        let left = CGPoint(x: leftEyeAnchor.x * imageSize.width, y: leftEyeAnchor.y * imageSize.height)
        let right = CGPoint(x: rightEyeAnchor.x * imageSize.width, y: rightEyeAnchor.y * imageSize.height)
        let source = CGPoint(x: right.x - left.x, y: right.y - left.y)
        let target = CGPoint(x: rightEye.x - leftEye.x, y: rightEye.y - leftEye.y)
        let sourceDistance = hypot(source.x, source.y)
        let targetDistance = hypot(target.x, target.y)
        guard sourceDistance.isFinite, targetDistance.isFinite,
            sourceDistance > 0, targetDistance > 0 else { return nil }
        let scale = targetDistance / sourceDistance
        let angle = atan2(target.y, target.x) - atan2(source.y, source.x)
        let scaledCosine = scale * cos(angle)
        let scaledSine = scale * sin(angle)
        let midpoint = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
        let translationX = (leftEye.x + rightEye.x) / 2 - scaledCosine * midpoint.x + scaledSine * midpoint.y
        let translationY = (leftEye.y + rightEye.y) / 2 - scaledSine * midpoint.x - scaledCosine * midpoint.y
        guard [scaledCosine, scaledSine, translationX, translationY].allSatisfy({ $0.isFinite }) else { return nil }
        return CGAffineTransform(
            a: scaledCosine, b: scaledSine, c: -scaledSine, d: scaledCosine,
            tx: translationX, ty: translationY
        )
    }
}
