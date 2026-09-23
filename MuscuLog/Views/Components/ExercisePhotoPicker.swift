import PhotosUI
import SwiftUI

extension ExercisePhotoPicker.Source: Identifiable {
    var id: Self { self }
}

/// Sélecteur de photo pour une machine : caméra (via `UIImagePickerController`,
/// car `PHPicker` ne propose pas la prise de vue) ou photothèque (via
/// `PHPickerViewController`, qui ne demande aucune permission).
struct ExercisePhotoPicker: UIViewControllerRepresentable {

    enum Source {
        case camera
        case library
    }

    let source: Source
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIViewController {
        switch source {
        case .camera:
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = context.coordinator
            return picker
        case .library:
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = context.coordinator
            return picker
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, PHPickerViewControllerDelegate, UINavigationControllerDelegate {
        private let parent: ExercisePhotoPicker

        init(_ parent: ExercisePhotoPicker) {
            self.parent = parent
        }

        // Caméra
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        // Photothèque
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                Task { @MainActor in
                    self.parent.onImage(image)
                }
            }
        }
    }
}
