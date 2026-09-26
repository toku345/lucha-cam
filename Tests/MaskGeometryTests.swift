import XCTest

final class MaskGeometryTests: XCTestCase {
    func testBothAnchorsLandOnEyesAfterTranslationScaleAndRotation() throws {
        let size = CGSize(width: 1254, height: 1254)
        for eyes in [
            (CGPoint(x: 120, y: 180), CGPoint(x: 320, y: 180)),
            (CGPoint(x: 50, y: 300), CGPoint(x: 200, y: 180)),
            (CGPoint(x: 420, y: 100), CGPoint(x: 300, y: 240))
        ] {
            let transform = try XCTUnwrap(MaskGeometry.transform(imageSize: size, leftEye: eyes.0, rightEye: eyes.1))
            for (anchor, expected) in [(MaskGeometry.leftEyeAnchor, eyes.0), (MaskGeometry.rightEyeAnchor, eyes.1)] {
                let mapped = CGPoint(x: anchor.x * size.width, y: anchor.y * size.height).applying(transform)
                XCTAssertEqual(mapped.x, expected.x, accuracy: 0.000001)
                XCTAssertEqual(mapped.y, expected.y, accuracy: 0.000001)
            }
            // A similarity transform must preserve aspect ratio and not reflect the PNG.
            XCTAssertEqual(hypot(transform.a, transform.b), hypot(transform.c, transform.d), accuracy: 0.000001)
            XCTAssertGreaterThan(transform.a * transform.d - transform.b * transform.c, 0)
        }
    }

    func testInvalidGeometryDoesNotProduceLayerTransform() {
        XCTAssertNil(MaskGeometry.transform(imageSize: .zero, leftEye: .zero, rightEye: CGPoint(x: 10, y: 0)))
        XCTAssertNil(MaskGeometry.transform(
            imageSize: CGSize(width: 100, height: 100), leftEye: .zero, rightEye: .zero
        ))
        XCTAssertNil(MaskGeometry.transform(
            imageSize: CGSize(width: 100, height: 100), leftEye: CGPoint(x: CGFloat.nan, y: 0), rightEye: .zero
        ))
    }
}
