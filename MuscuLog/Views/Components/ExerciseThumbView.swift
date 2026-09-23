import SwiftUI

/// Vignette d'exercice : photo de la machine si disponible (photo locale,
/// sinon URL de référence chargée en asynchrone), pictogramme du muscle
/// principal en repli.
struct ExerciseThumbView: View {

    let exercise: Exercise
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 8

    @State private var remoteImage: UIImage?

    private var placeholderSymbol: String {
        exercise.primaryMuscleGroup?.symbolName ?? "dumbbell.fill"
    }

    private var placeholderTint: Color {
        exercise.primaryMuscleGroup?.tint ?? .accentColor
    }

    var body: some View {
        ZStack {
            if let image = exercise.thumbnail {
                imageContent(image)
            } else if let remoteImage {
                imageContent(remoteImage)
            } else {
                if let urlString = exercise.remoteImageURL {
                    remoteLoader(urlString)
                } else {
                    placeholder
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func imageContent(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
    }

    private func remoteLoader(_ urlString: String) -> some View {
        Color(.tertiarySystemFill)
            .overlay {
                ProgressView()
            }
            .task(id: urlString) {
                ImageStore.loadRemote(urlString) { image in
                    remoteImage = image
                }
            }
    }

    private var placeholder: some View {
        placeholderTint.opacity(0.14)
            .overlay {
                Image(systemName: placeholderSymbol)
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(placeholderTint)
            }
    }
}
