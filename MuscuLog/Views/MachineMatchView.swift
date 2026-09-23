import SwiftData
import SwiftUI
import UIKit

/// Service de reconnaissance orienté vues : prépare l'instantané de la
/// bibliothèque (MainActor), lance l'analyse Vision en arrière-plan et
/// traduit le résultat en propositions concrètes.
@MainActor
enum MachineRecognitionService {

    struct Result {
        /// Machine déjà enregistrée reconnue sur la photo, s'il y en a une.
        let matchedExercise: Exercise?
        /// Confiance du match visuel (0…1), `nil` si aucun.
        let confidence: Double?
        /// Famille de machine proposée (détection de type ou nom reconnu).
        let family: MachineFamily?
        /// Exercices de la bibliothèque à faire sur cette machine.
        let suggestions: [Exercise]
    }

    /// Analyse une photo de machine contre la bibliothèque fournie.
    static func recognize(image: UIImage, library: [Exercise]) async -> Result {
        let entries = library.compactMap { exercise -> MachineRecognizer.SnapshotEntry? in
            guard let photo = exercise.photo else { return nil }
            return MachineRecognizer.SnapshotEntry(id: exercise.id, name: exercise.name, image: photo)
        }
        let analysis = await MachineRecognizer.analyze(image: image, library: entries)

        var suggestions: [Exercise] = []
        var matched: Exercise?
        if let matchID = analysis.visualMatchID {
            matched = library.first { $0.id == matchID }
        }
        if let matched {
            suggestions = suggestionsForMatch(matched, analysis: analysis, library: library)
        } else if let family = analysis.family {
            suggestions = suggestionsForFamily(family, library: library)
        }

        return Result(
            matchedExercise: matched,
            confidence: analysis.confidence,
            family: analysis.family,
            suggestions: suggestions
        )
    }

    /// Exercices à faire sur la machine reconnue : le mouvement enregistré
    /// d'abord, puis les types de la même famille, puis les mouvements
    /// partageant un muscle.
    private static func suggestionsForMatch(
        _ matched: Exercise,
        analysis: MachineRecognizer.Analysis,
        library: [Exercise]
    ) -> [Exercise] {
        var result = [matched]
        let family = analysis.family
        for name in family?.typicalExercises ?? [] {
            guard result.count < 6 else { break }
            if let exercise = library.first(where: { $0.name.foldedForSearch == name.foldedForSearch }),
               !result.contains(where: { $0.id == exercise.id }) {
                result.append(exercise)
            }
        }
        for exercise in library where result.count < 6 {
            if result.contains(where: { $0.id == exercise.id }) { continue }
            if exercise.muscleGroups.contains(where: { matched.muscleGroups.contains($0) }) {
                result.append(exercise)
            }
        }
        return result
    }

    /// Exercices de la bibliothèque pour une famille détectée sur la photo.
    private static func suggestionsForFamily(
        _ family: MachineFamily,
        library: [Exercise]
    ) -> [Exercise] {
        var result: [Exercise] = []
        for name in family.typicalExercises {
            if let exercise = library.first(where: { $0.name.foldedForSearch == name.foldedForSearch }) {
                result.append(exercise)
            }
        }
        if result.isEmpty {
            result = library.filter { exercise in
                exercise.muscleGroups.contains { family.muscleGroups.contains($0) }
            }
        }
        return Array(result.prefix(6))
    }
}

/// Écran « machine reconnue » : montre la photo analysée, ce que l'app en a
/// déduit, les exercices à faire dessus, et permet de créer un exercice
/// prérempli pour cette machine.
struct MachineMatchView: View {

    let image: UIImage
    let library: [Exercise]
    /// Appelé quand l'utilisateur choisit un exercice (depuis une séance).
    /// `nil` en contexte bibliothèque : les suggestions naviguent vers le détail.
    var onPick: ((Exercise) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var result: MachineRecognitionService.Result?
    @State private var isAnalyzing = true
    @State private var isCreating = false
    @State private var pendingFamily: MachineFamily?

    var body: some View {
        NavigationStack {
            Group {
                if isAnalyzing {
                    ProgressView("Analyse de la machine…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let result {
                    content(for: result)
                }
            }
            .navigationTitle("Machine reconnue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(isPresented: $isCreating) {
                ExerciseEditView(exercise: nil, initialImage: image, initialFamily: pendingFamily)
            }
            .task {
                result = await MachineRecognitionService.recognize(image: image, library: library)
                isAnalyzing = false
            }
        }
    }

    // MARK: - Contenu

    @ViewBuilder
    private func content(for result: MachineRecognitionService.Result) -> some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipShape(.rect(cornerRadius: 12))
                    verdict(for: result)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)

            if result.matchedExercise == nil, result.family == nil {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                        Text("Machine non identifiée")
                            .font(.headline)
                        Text("Prends la machine de trois quarts avec le poste de travail bien visible, ou choisis son type ci-dessous.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                familyChoiceSection
            } else {
                suggestionsSection(for: result)
            }

            Section {
                Button {
                    pendingFamily = result.family
                    isCreating = true
                } label: {
                    Label("Créer un exercice sur cette machine", systemImage: "plus.circle.fill")
                }
            } footer: {
                Text("Nom, muscles et équipement préremplis d'après la machine reconnue — vérifie et ajuste avant d'enregistrer.")
            }
        }
    }

    @ViewBuilder
    private func verdict(for result: MachineRecognitionService.Result) -> some View {
        if let matched = result.matchedExercise {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("C'est ta machine : \(matched.name)")
                        .font(.headline)
                    if let confidence = result.confidence {
                        Text("Reconnue sur ta photo (à \(Int(confidence * 100)) %)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } else if let family = result.family {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("On dirait une \(family.title)")
                        .font(.headline)
                    Text("Type reconnu sur la photo — vérifie la suggestion ci-dessous.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    @ViewBuilder
    private func suggestionsSection(for result: MachineRecognitionService.Result) -> some View {
        Section {
            if result.suggestions.isEmpty {
                Text("Aucun exercice existant pour cette machine — crée-le ci-dessous.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(result.suggestions) { exercise in
                    suggestionRow(for: exercise, in: result)
                }
            }
        } header: {
            Text("Exercices à faire dessus")
                .textCase(nil)
        }
    }

    @ViewBuilder
    private func suggestionRow(
        for exercise: Exercise,
        in result: MachineRecognitionService.Result
    ) -> some View {
        let rowContent = HStack(spacing: 10) {
            ExerciseThumbView(exercise: exercise, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                if let matched = result.matchedExercise, matched.id == exercise.id {
                    Text("Machine reconnue")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                }
                HStack(spacing: 4) {
                    ForEach(exercise.muscleGroups) { group in
                        MuscleTag(group: group)
                    }
                }
            }
            Spacer()
            if onPick != nil {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(.rect)

        if let onPick {
            Button {
                onPick(exercise)
                Haptics.success()
                dismiss()
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                ExerciseDetailView(exercise: exercise)
            } label: {
                rowContent
            }
        }
    }

    /// Choix manuel de la famille quand la photo n'a rien donné.
    private var familyChoiceSection: some View {
        Section {
            ForEach(MachineFamily.all) { family in
                Button {
                    pendingFamily = family
                    isCreating = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: family.fallbackGroup.symbolName)
                            .foregroundStyle(family.fallbackGroup.tint)
                            .frame(width: 22)
                        Text(family.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Quel type d'appareil est-ce ?")
                .textCase(nil)
        } footer: {
            Text("L'exercice sera prérempli avec les muscles de la machine choisie.")
        }
    }
}
