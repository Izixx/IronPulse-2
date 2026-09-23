import SwiftUI
import SwiftData
import UIKit

/// Photo et image de référence d'un exercice.
///
/// Deux sources possibles, par ordre de priorité d'affichage :
/// 1. **Une photo prise par l'utilisateur** (ex. la machine Technogym du
///    club), compressée puis stockée hors base (`externalStorage`) ;
/// 2. **Une URL d'image** collée en référence (réservoir, Technogym, etc.).
extension Exercise {

    // MARK: - Accès mémoire

    /// La photo prise en salle, prête à afficher.
    var photo: UIImage? {
        if let cachedPhoto { return cachedPhoto }
        guard let data = photoData, let image = UIImage(data: data) else { return nil }
        cachedPhoto = image
        return image
    }

    /// Vignette pour les listes et grilles (dégrade en photo si absente).
    var thumbnail: UIImage? {
        if let cachedThumbnail { return cachedThumbnail }
        let image: UIImage?
        if let thumbData, let decoded = UIImage(data: thumbData) {
            image = decoded
        } else if let photo {
            image = ImageStore.makeListThumbnail(from: photo)
        } else {
            image = nil
        }
        cachedThumbnail = image
        return image
    }

    var hasAnyImage: Bool { photoData != nil || (remoteImageURL?.isEmpty == false) }

    /// Remplace la photo (et régénère la vignette). `nil` supprime tout.
    func setPhoto(_ image: UIImage?) {
        guard let image else {
            photoData = nil
            thumbnailData = nil
            cachedPhoto = nil
            cachedThumbnail = nil
            return
        }
        guard let processed = ImageStore.process(image) else { return }
        photoData = processed.jpegData(compressionQuality: ImageStore.jpegQuality)
        cachedPhoto = processed
        if let thumb = ImageStore.makeListThumbnail(from: processed) {
            thumbnailData = thumb.jpegData(compressionQuality: ImageStore.jpegQuality)
            cachedThumbnail = thumb
        }
    }

    func setRemoteImageURL(_ urlString: String?) {
        let trimmed = urlString?.trimmingCharacters(in: .whitespacesAndNewlines)
        remoteImageURL = (trimmed?.isEmpty == false) ? trimmed : nil
    }
}
