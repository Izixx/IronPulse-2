import Foundation
import SwiftData

/// Aides d'attachement des relations parent → enfant.
///
/// SwiftData maintient normalement la relation inverse dès qu'on affecte le
/// côté enfant. En pratique cette mise à jour peut être différée, ce qui donne
/// des listes vides juste après une insertion et des écrans qui ne se
/// rafraîchissent pas. Ces méthodes fixent les deux côtés explicitement, et le
/// test de présence évite tout doublon quand SwiftData a déjà fait le travail.
extension WorkoutSession {
    func attach(_ item: WorkoutExercise) {
        item.session = self
        if !exercises.contains(where: { $0.id == item.id }) {
            exercises.append(item)
        }
    }
}

extension WorkoutExercise {
    func attach(_ set: SetEntry) {
        set.workoutExercise = self
        if !sets.contains(where: { $0.id == set.id }) {
            sets.append(set)
        }
    }
}

extension Routine {
    func attach(_ day: RoutineDay) {
        day.routine = self
        if !days.contains(where: { $0.id == day.id }) {
            days.append(day)
        }
    }
}

extension RoutineDay {
    func attach(_ line: RoutineDayExercise) {
        line.day = self
        if !exercises.contains(where: { $0.id == line.id }) {
            exercises.append(line)
        }
    }
}
