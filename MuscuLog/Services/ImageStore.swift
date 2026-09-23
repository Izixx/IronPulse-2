import UIKit

/// Chargement, normalisation et persistance des photos d'exercices.
///
/// Les photos de machines sont compressées et redimensionnées **à l'import**
/// (long bord 1280 px, JPEG ~75 %) puis stockées **hors de la base** SwiftData
/// (attribut `externalStorage`), pour ne pas alourdir le conteneur ni le
/// fichier d'export JSON.
enum ImageStore {
    static let maxDimension: CGFloat = 1280
    static let jpegQuality: CGFloat = 0.75
    static let thumbnailSize: CGFloat = 320
    static let listThumbnailSize: CGFloat = 120
    private static let remoteCache = NSCache<NSString, UIImage>()

    // MARK: - Import

    /// Normalise une photo importée (caméra ou photothèque) : orientation,
    /// redimensionnement si besoin, recompression JPEG.
    static func process(_ image: UIImage) -> UIImage? {
        let maxSide = max(image.size.width, image.upscaledHeight)
        guard maxSide > 0 else { return nil }
        let target = maxSide > maxDimension
            ? image.scaled(by: maxDimension / maxSide) ?? image
            : image
        return target.jpegData(compressionQuality: jpegQuality).flatMap(UIImage.init(data:))
    }

    /// Vignette carrée centrée (grille de l'éditeur, onglet Photos du picker).
    static func makeThumbnail(from image: UIImage) -> UIImage? {
        guard let square = centerCroppedSquare(image) else { return nil }
        let side = max(square.size.width, square.upscaledHeight)
        guard side > thumbnailSize else { return square }
        return square.scaled(by: thumbnailSize / side)
    }

    /// Version basse résolution pour les petites vignettes de listes.
    static func makeListThumbnail(from image: UIImage) -> UIImage? {
        guard let square = centerCroppedSquare(image) else { return nil }
        let side = max(square.size.width, square.upscaledHeight)
        guard side > listThumbnailSize else { return square }
        return square.scaled(by: listThumbnailSize / side)
    }

    private static func centerCroppedSquare(_ image: UIImage) -> UIImage? {
        let side = min(image.size.width, image.upscaledHeight)
        guard side > 0 else { return nil }
        let cropRect = CGRect(
            x: (image.size.width - side) / 2,
            y: (image.upscaledHeight - side) / 2,
            width: side,
            height: side
        )
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    // MARK: - Distant

    /// Charge une image distante (URL de référence), avec cache mémoire.
    /// Appelée depuis la vue (MainActor) ; le callback arrive sur MainActor.
    @MainActor
    static func loadRemote(_ urlString: String, completion: @escaping @MainActor (UIImage?) -> Void) {
        if let cached = remoteCache.object(forKey: urlString as NSString) {
            completion(cached)
            return
        }
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        URLSession.shared.dataTask(with: request) { data, _, error in
            let image = (error == nil ? data : nil).flatMap { $0.isEmpty ? nil : UIImage(data: $0) }
            if let image {
                remoteCache.setObject(image, forKey: urlString as NSString)
            }
            Task { @MainActor in
                completion(image)
            }
        }.resume()
    }
}

// MARK: - Aides UIImage

extension UIImage {
    /// Hauteur en pixels physiques (les photos caméra arrivent avec `scale`).
    var upscaledHeight: CGFloat { size.height * scale }

    /// Largeur en pixels physiques.
    var upscaledWidth: CGFloat { size.width * scale }

    /// Redimensionne en préservant le ratio et l'orientation.
    func scaled(by factor: CGFloat) -> UIImage? {
        guard factor > 0 else { return nil }
        guard factor < 1 else { return self }
        let newSize = CGSize(width: size.width * factor, height: size.height * factor)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
