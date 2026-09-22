import Foundation
import SwiftData

/// Une routine réutilisable (Push/Pull/Legs, Haut/Bas, Full body, …).
/// Une seule routine est active à la fois : c'est celle qui pilote la
/// suggestion de séance du jour.
@Model
final class Routine {

    var id: UUID = UUID()
    var name: String = ""
    var isActive: Bool = false
    /// Index du prochain jour à faire dans le cycle.
    var nextDayIndex: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \RoutineDay.routine)
    var days: [RoutineDay] = []

    init(name: String, isActive: Bool = false, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.isActive = isActive
        self.nextDayIndex = 0
        self.createdAt = createdAt
        self.days = []
    }

    var orderedDays: [RoutineDay] {
        days.sorted { $0.order < $1.order }
    }

    /// Prochain jour du cycle (celui qu'on va enchaîner aujourd'hui).
    var nextDay: RoutineDay? {
        let ordered = orderedDays
        guard !ordered.isEmpty else { return nil }
        let index = ((nextDayIndex % ordered.count) + ordered.count) % ordered.count
        return ordered[index]
    }

    /// Avance le curseur du cycle après une séance terminée.
    func advanceCycle() {
        let count = orderedDays.count
        guard count > 0 else {
            nextDayIndex = 0
            return
        }
        nextDayIndex = (nextDayIndex + 1) % count
    }

    func rewindCycle() {
        let count = orderedDays.count
        guard count > 0 else {
            nextDayIndex = 0
            return
        }
        nextDayIndex = (nextDayIndex - 1 + count) % count
    }
}

@Model
final class RoutineDay {

    var id: UUID = UUID()
    var name: String = ""
    var order: Int = 0
    var routine: Routine?

    @Relationship(deleteRule: .cascade, inverse: \RoutineDayExercise.day)
    var exercises: [RoutineDayExercise] = []

    init(name: String, order: Int) {
        self.id = UUID()
        self.name = name
        self.order = order
        self.routine = nil
        self.exercises = []
    }

    var orderedExercises: [RoutineDayExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    var muscleGroups: [MuscleGroup] {
        var seen: Set<MuscleGroup> = []
        var result: [MuscleGroup] = []
        for item in orderedExercises {
            for group in item.muscleGroups where seen.insert(group).inserted {
                result.append(group)
            }
        }
        return result
    }
}

/// Ligne d'un jour de routine : un exercice et une cible de séries/répétitions.
@Model
final class RoutineDayExercise {

    var id: UUID = UUID()
    var order: Int = 0
    var targetSets: Int = 3
    var targetReps: Int = 10
    var day: RoutineDay?
    var exercise: Exercise?

    init(exercise: Exercise?, order: Int, targetSets: Int = 3, targetReps: Int = 10) {
        self.id = UUID()
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.day = nil
        self.exercise = exercise
    }

    var muscleGroups: [MuscleGroup] { exercise?.muscleGroups ?? [] }

    var displayName: String { exercise?.name ?? "Exercice supprimé" }

    var targetSummary: String { "\(targetSets) × \(targetReps)" }
}
