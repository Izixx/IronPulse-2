import Foundation
import SwiftData
import UIKit

/// Un mouvement de la bibliothèque (prérempli ou créé par l'utilisateur).
@Model
final class Exercise {

    var id: UUID = UUID()
    var name: String = ""
    /// Stocké sous forme de `[String]` de `MuscleGroup.rawValue` : le type le
    /// plus stable pour SwiftData, et lisible dans une base exportée.
    var muscleGroupsRaw: [String] = []
    var equipment: String?
    var isCustom: Bool = false
    /// On archive au lieu de supprimer : l'historique reste intact.
    var isArchived: Bool = false
    var createdAt: Date = Date()

    // MARK: - Photo (logique dans ExercisePhoto.swift)

    /// Photo JPEG de l'appareil, stockée hors base pour ne pas gonfler le
    /// conteneur SwiftData ni le fichier d'export JSON.
    @Attribute(.externalStorage) var photoData: Data? = nil
    /// Vignette carrée basse résolution pour les listes.
    @Attribute(.externalStorage) var thumbnailData: Data? = nil
    /// URL d'une image de référence (facultative).
    var remoteImageURL: String? = nil
    /// Caches mémoire (non persistés) — `internal` car utilisés par
    /// l'extension du fichier ExercisePhoto.swift.
    @Transient var cachedPhoto: UIImage? = nil
    @Transient var cachedThumbnail: UIImage? = nil

    /// Supprimer un exercice ne doit jamais effacer l'historique : les séries
    /// passées survivent, elles perdent juste leur libellé.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise)
    var entries: [WorkoutExercise] = []

    init(
        name: String,
        muscleGroups: [MuscleGroup],
        equipment: String? = nil,
        isCustom: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.muscleGroupsRaw = muscleGroups.map(\.rawValue)
        self.equipment = equipment
        self.isCustom = isCustom
        self.isArchived = false
        self.createdAt = createdAt
        self.photoData = nil
        self.thumbnailData = nil
        self.remoteImageURL = nil
    }

    var muscleGroups: [MuscleGroup] {
        muscleGroupsRaw.compactMap(MuscleGroup.init(rawValue:))
    }

    func setMuscleGroups(_ groups: [MuscleGroup]) {
        muscleGroupsRaw = groups.map(\.rawValue)
    }

    var primaryMuscleGroup: MuscleGroup? {
        muscleGroups.first
    }
}

extension Exercise {
    /// Recherche insensible à la casse ET aux accents (« developpe couche »
    /// doit trouver « Développé couché »).
    func matches(searchText: String) -> Bool {
        let needle = searchText.foldedForSearch
        guard !needle.isEmpty else { return true }
        if name.foldedForSearch.contains(needle) { return true }
        if let equipment, equipment.foldedForSearch.contains(needle) { return true }
        return muscleGroups.contains { $0.title.foldedForSearch.contains(needle) }
    }
}

extension String {
    /// Minuscules sans accents ni diacritiques, pour la recherche et l'export.
    var foldedForSearch: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
