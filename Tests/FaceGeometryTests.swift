import XCTest

final class FaceGeometryTests: XCTestCase {
    func testEyeMeanIsScaledAndOffsetWithinFace() throws {
        let point = try XCTUnwrap(FaceGeometry.eyeCenter(
            [CGPoint(x: 0.2, y: 0.6), CGPoint(x: 0.4, y: 0.8)],
            in: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.4)
        ))
        XCTAssertEqual(point.x, 0.25, accuracy: 0.000001)
        XCTAssertEqual(point.y, 0.48, accuracy: 0.000001)
    }

    func testMissingEyeHasNoRepresentativePoint() {
        XCTAssertNil(FaceGeometry.eyeCenter([], in: CGRect(x: 0, y: 0, width: 1, height: 1)))
    }

    func testOriginConversionDoesNotMirrorX() {
        let point = FaceGeometry.capturePoint(fromVision: CGPoint(x: 0.2, y: 0.7))
        XCTAssertEqual(point.x, 0.2, accuracy: 0.000001)
        XCTAssertEqual(point.y, 0.3, accuracy: 0.000001)
    }

    func testRectangleUsesItsTopEdgeWhenFlippingOrigin() {
        let rect = FaceGeometry.metadataRect(fromVision: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4))
        XCTAssertEqual(rect.minX, 0.1, accuracy: 0.000001)
        XCTAssertEqual(rect.minY, 0.4, accuracy: 0.000001)
        XCTAssertEqual(rect.width, 0.3, accuracy: 0.000001)
        XCTAssertEqual(rect.height, 0.4, accuracy: 0.000001)
    }
}
