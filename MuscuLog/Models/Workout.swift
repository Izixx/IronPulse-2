import Foundation
import SwiftData

/// Une séance d'entraînement. Une séance créée mais non terminée
/// (`endedAt == nil`) est la « séance en cours » de l'application.
@Model
final class WorkoutSession {

    var id: UUID = UUID()
    var date: Date = Date()
    var startedAt: Date = Date()
    var endedAt: Date?
    /// Ressenti / note libre, optionnel.
    var note: String?
    /// Nom de la routine utilisée, dupliqué ici pour que l'historique reste
    /// lisible même si la routine est supprimée plus tard.
    var routineName: String?
    var routineDayName: String?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.session)
    var exercises: [WorkoutExercise] = []

    init(
        date: Date = .now,
        note: String? = nil,
        routineName: String? = nil,
        routineDayName: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.startedAt = date
        self.endedAt = nil
        self.note = note
        self.routineName = routineName
        self.routineDayName = routineDayName
        self.exercises = []
    }

    var isInProgress: Bool { endedAt == nil }

    var orderedExercises: [WorkoutExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    var duration: TimeInterval? {
        endedAt.map { $0.timeIntervalSince(startedAt) }
    }

    /// Séries de travail (les échauffements sont comptés à part).
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.workingSetCount }
    }

    var totalReps: Int {
        exercises.reduce(0) { total, item in
            total + item.workingSets.reduce(0) { $0 + $1.reps }
        }
    }

    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.volume }
    }

    /// Groupes musculaires sollicités pendant la séance (dédupliqués).
    var muscleGroups: Set<MuscleGroup> {
        var result: Set<MuscleGroup> = []
        for item in exercises {
            result.formUnion(item.muscleGroups)
        }
        return result
    }

    /// Titre lisible : « Push », « Séance libre », …
    var title: String {
        if let routineDayName, !routineDayName.isEmpty {
            return routineName.map { "\($0) · \(routineDayName)" } ?? routineDayName
        }
        if let routineName, !routineName.isEmpty { return routineName }
        return "Séance libre"
    }

    func nextOrder() -> Int {
        (exercises.map(\.order).max() ?? -1) + 1
    }
}

/// Un exercice « instancié » dans une séance donnée.
@Model
final class WorkoutExercise {

    var id: UUID = UUID()
    var order: Int = 0
    var addedAt: Date = Date()
    var session: WorkoutSession?
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.workoutExercise)
    var sets: [SetEntry] = []

    init(exercise: Exercise?, order: Int) {
        self.id = UUID()
        self.order = order
        self.addedAt = .now
        self.session = nil
        self.exercise = exercise
        self.sets = []
    }

    var displayName: String { exercise?.name ?? "Exercice supprimé" }
    var muscleGroups: [MuscleGroup] { exercise?.muscleGroups ?? [] }

    var orderedSets: [SetEntry] {
        sets.sorted { $0.order < $1.order }
    }

    var workingSets: [SetEntry] { sets.filter { !$0.isWarmup } }

    var workingSetCount: Int { workingSets.count }

    /// Tonnage de travail : les séries d'échauffement ne comptent pas dans les
    /// statistiques, sinon tous les graphiques seraient faussés.
    var volume: Double { workingSets.reduce(0) { $0 + $1.volume } }

    var bestWorkingSet: SetEntry? {
        workingSets.max { $0.weight < $1.weight }
    }

    var maxWeight: Double { workingSets.map(\.weight).max() ?? 0 }

    /// Meilleur 1RM estimé sur cet exercice, pour cette séance.
    var estimated1RM: Double {
        workingSets.map(\.estimated1RM).max() ?? 0
    }

    var topReps: Int { workingSets.map(\.reps).max() ?? 0 }

    func nextOrder() -> Int {
        (sets.map(\.order).max() ?? -1) + 1
    }
}

/// Une série : le cœur de la donnée d'entraînement.
@Model
final class SetEntry {

    var id: UUID = UUID()
    var order: Int = 0
    var reps: Int = 0
    /// En kilogrammes.
    var weight: Double = 0
    /// RPE optionnel (difficulté ressentie, échelle 6 → 10).
    var rpe: Double?
    var isWarmup: Bool = false
    var loggedAt: Date = Date()
    var workoutExercise: WorkoutExercise?

    init(
        order: Int,
        reps: Int,
        weight: Double,
        rpe: Double? = nil,
        isWarmup: Bool = false,
        loggedAt: Date = .now
    ) {
        self.id = UUID()
        self.order = order
        self.reps = reps
        self.weight = weight
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.loggedAt = loggedAt
        self.workoutExercise = nil
    }

    var volume: Double { Double(reps) * weight }

    var estimated1RM: Double { OneRepMax.estimate(weight: weight, reps: reps) }

    var summary: String {
        var text = "\(reps) × \(weight.cleanWeight) kg"
        if let rpe { text += " · RPE \(rpe.cleanWeight)" }
        return text
    }
}
