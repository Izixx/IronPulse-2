import XCTest
@testable import MuscuLog

/// Vérifie le pipeline d'import des photos de machines : redimensionnement,
/// vignette carrée, compression JPEG.
@MainActor
final class ImageStoreTests: XCTestCase {

    /// Image pleine de `width × height` pixels (scale 1, comme le renderer).
    private func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            .image { context in
                UIColor.systemRed.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
    }

    func testProcessDownscalesOversizedPhoto() throws {
        let processed = try XCTUnwrap(ImageStore.process(makeImage(width: 4000, height: 3000)))
        XCTAssertEqual(max(processed.upscaledWidth, processed.upscaledHeight), ImageStore.maxDimension)
        XCTAssertNotNil(processed.jpegData(compressionQuality: 1), "La sortie doit être un JPEG décodable")
    }

    func testProcessKeepsSmallPhotoUnscaled() throws {
        let processed = try XCTUnwrap(ImageStore.process(makeImage(width: 800, height: 600)))
        XCTAssertEqual(processed.upscaledWidth, 800)
        XCTAssertEqual(processed.upscaledHeight, 600)
    }

    func testListThumbnailIsSquareAndBounded() throws {
        let source = try XCTUnwrap(ImageStore.process(makeImage(width: 1600, height: 900)))
        let thumb = try XCTUnwrap(ImageStore.makeListThumbnail(from: source))
        XCTAssertEqual(thumb.upscaledWidth, thumb.upscaledHeight, "La vignette doit être carrée")
        XCTAssertLessThanOrEqual(max(thumb.upscaledWidth, thumb.upscaledHeight), ImageStore.listThumbnailSize)
    }

    func testThumbnailNeverUpscales() throws {
        let tiny = makeImage(width: 60, height: 60)
        let thumb = try XCTUnwrap(ImageStore.makeListThumbnail(from: tiny))
        XCTAssertEqual(thumb.upscaledWidth, 60, "Une petite image ne doit pas être agrandie")
    }

    func testScaledByMoreThanOneReturnsSameImage() throws {
        let image = makeImage(width: 100, height: 50)
        XCTAssertNil(image.scaled(by: 0), "Facteur 0 invalide")
        XCTAssertTrue(image.scaled(by: 2) === image, "Un agrandissement renvoie l'image inchangée")
    }

    func testExercisePhotoRoundTrip() {
        let exercise = Exercise(name: "Presse à cuisses", muscleGroups: [.quadriceps])
        XCTAssertNil(exercise.photo)
        XCTAssertFalse(exercise.hasAnyImage)

        exercise.setPhoto(makeImage(width: 2400, height: 1600))
        XCTAssertNotNil(exercise.photo, "La photo doit être stockée et décodable")
        XCTAssertNotNil(exercise.thumbnail, "La vignette doit être générée automatiquement")
        XCTAssertTrue(exercise.hasAnyImage)

        exercise.setPhoto(nil)
        XCTAssertNil(exercise.photo)
        XCTAssertNil(exercise.thumbnail)
        XCTAssertFalse(exercise.hasAnyImage)
    }
}
