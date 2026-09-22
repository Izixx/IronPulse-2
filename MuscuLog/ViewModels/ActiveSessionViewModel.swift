import Foundation
import SwiftData
import SwiftUI

/// Pilote la séance en cours : création, ajout d'exercices, saisie des séries,
/// minuteur de repos et clôture.
///
/// La séance en cours est un vrai `WorkoutSession` persisté dont `endedAt` est
/// `nil`. Conséquence : si l'app est tuée en pleine séance (batterie, sideload
/// qui expire…), on la retrouve intacte au prochain lancement.
@Observable
@MainActor
final class ActiveSessionViewModel {

    // MARK: - Types annexes

    struct Toast: Identifiable, Equatable {
        enum Kind { case info, success, warning }
        let id = UUID()
        var text: String
        var kind: Kind
    }

    enum Keys {
        static let restDuration = "musculog.restDuration"
        static let restNotifications = "musculog.restNotifications"
        static let reminderEnabled = "musculog.reminderEnabled"
        static let reminderHour = "musculog.reminderHour"
        static let reminderMinute = "musculog.reminderMinute"
    }

    // MARK: - État

    private let context: ModelContext

    /// `nil` quand aucune séance n'est en cours.
    var session: WorkoutSession?

    /// Date de fin du repos en cours. On ne fait tourner **aucun** timer :
    /// l'interface recompte le temps restant à chaque rafraîchissement, et une
    /// notification locale prévient même app fermée.
    var restEndsAt: Date?

    var restDuration: TimeInterval {
        didSet { UserDefaults.standard.set(restDuration, forKey: Keys.restDuration) }
    }

    var restNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(restNotificationsEnabled, forKey: Keys.restNotifications) }
    }

    var toast: Toast?

    init(context: ModelContext) {
        self.context = context
        let stored = UserDefaults.standard.object(forKey: Keys.restDuration) as? Double
        self.restDuration = stored ?? 120
        self.restNotificationsEnabled =
            UserDefaults.standard.object(forKey: Keys.restNotifications) as? Bool ?? true
    }

    // MARK: - Repos

    var isResting: Bool {
        guard let restEndsAt else { return false }
        return restEndsAt > .now
    }

    var restRemaining: TimeInterval {
        guard let restEndsAt else { return 0 }
        return max(0, restEndsAt.timeIntervalSinceNow)
    }

    var restProgress: Double {
        guard restDuration > 0, let restEndsAt else { return 0 }
        let elapsed = restDuration - restEndsAt.timeIntervalSinceNow
        return min(1, max(0, elapsed / restDuration))
    }

    func startRest(exerciseName: String?, duration: TimeInterval? = nil) {
        let seconds = duration ?? restDuration
        restEndsAt = Date.now.addingTimeInterval(seconds)
        if restNotificationsEnabled {
            NotificationService.scheduleRestEnd(after: seconds, exerciseName: exerciseName)
        }
        Haptics.tap()
    }

    func stopRest() {
        restEndsAt = nil
        NotificationService.cancelRestEnd()
    }

    func extendRest(by seconds: TimeInterval) {
        guard let current = restEndsAt else { return }
        let newEnd = current.addingTimeInterval(seconds)
        restEndsAt = newEnd
        if restNotificationsEnabled {
            NotificationService.scheduleRestEnd(
                after: max(1, newEnd.timeIntervalSinceNow),
                exerciseName: nil
            )
        }
    }

    // MARK: - Cycle de vie de la séance

    func save() {
        try? context.save()
    }

    /// Retrouve une séance laissée en cours lors d'un lancement précédent.
    func restoreInProgressSession() {
        guard session == nil else { return }
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        )
        guard let candidates = try? context.fetch(descriptor) else { return }
        session = candidates.first { $0.endedAt == nil }
    }

    @discardableResult
    func startSession(
        at date: Date = .now,
        note: String? = nil,
        routine: Routine? = nil,
        routineDay: RoutineDay? = nil
    ) -> WorkoutSession {
        if let session { return session }

        let new = WorkoutSession(
            date: date,
            note: note,
            routineName: routine?.name,
            routineDayName: routineDay?.name
        )
        context.insert(new)
        session = new
        save()
        Haptics.success()
        return new
    }

    /// Démarre une séance et la remplit avec le jour de routine demandé.
    func startSession(from routine: Routine, day: RoutineDay, history: [WorkoutSession]) {
        let new = startSession(routine: routine, routineDay: day)
        for line in day.orderedExercises {
            guard let exercise = line.exercise else { continue }
            addExercise(
                exercise,
                to: new,
                defaultSets: line.targetSets,
                defaultReps: line.targetReps,
                history: history
            )
        }
        toast = Toast(text: "\(day.name) prêt : \(new.exercises.count) exercices", kind: .success)
    }

    /// Séance ciblée construite à partir des muscles à travailler aujourd'hui.
    func startSession(for groups: [MuscleGroup], library: [Exercise], history: [WorkoutSession]) {
        let new = startSession()
        let targets = Array(groups.prefix(3))

        for group in targets {
            // On privilégie un exercice composé (plusieurs groupes) par muscle.
            let candidates = library
                .filter { !$0.isArchived && $0.muscleGroups.contains(group) }
                .sorted { lhs, rhs in
                    if lhs.muscleGroups.count != rhs.muscleGroups.count {
                        return lhs.muscleGroups.count > rhs.muscleGroups.count
                    }
                    return lhs.name < rhs.name
                }
            guard let pick = candidates.first else { continue }
            if new.exercises.contains(where: { $0.exercise?.id == pick.id }) { continue }
            addExercise(pick, to: new, defaultSets: 3, defaultReps: 10, history: history)
        }

        toast = Toast(
            text: new.exercises.isEmpty
                ? "Aucun exercice trouvé pour ces muscles"
                : "Séance générée : \(new.exercises.count) exercices",
            kind: new.exercises.isEmpty ? .warning : .success
        )
    }

    /// Recopie la dernière séance terminée, valeurs comprises.
    func duplicateLastSession(from history: [WorkoutSession]) {
        let last = history
            .filter { !$0.isInProgress && !$0.orderedExercises.isEmpty }
            .max { $0.date < $1.date }
        guard let last else {
            toast = Toast(text: "Aucune séance précédente à recopier", kind: .warning)
            return
        }

        let new = startSession(routineName: last.routineName, routineDayName: last.routineDayName)
        for item in last.orderedExercises {
            guard let exercise = item.exercise else { continue }
            let copy = WorkoutExercise(exercise: exercise, order: new.nextOrder())
            context.insert(copy)
            new.attach(copy)
            for set in item.orderedSets {
                let copySet = SetEntry(
                    order: copy.nextOrder(),
                    reps: set.reps,
                    weight: set.weight,
                    rpe: nil,
                    isWarmup: set.isWarmup
                )
                context.insert(copySet)
                copy.attach(copySet)
            }
        }
        save()
        Haptics.success()
        toast = Toast(text: "Séance du \(last.date.shortDayLabel) recopiée", kind: .success)
    }

    private func startSession(routineName: String?, routineDayName: String?) -> WorkoutSession {
        if let session { return session }
        let new = WorkoutSession(routineName: routineName, routineDayName: routineDayName)
        context.insert(new)
        session = new
        return new
    }

    /// Clôture la séance. Une séance totalement vide est simplement annulée.
    func finish(activeRoutine: Routine?, onFinish: ((WorkoutSession) -> Void)? = nil) {
        guard let session else { return }

        let hasAnySet = session.exercises.contains { !$0.sets.isEmpty }
        guard hasAnySet else {
            discard(reason: "Séance vide : rien à enregistrer")
            return
        }

        // Les exercices ajoutés puis laissés vides ne polluent pas l'historique.
        // On retire aussi la référence du côté séance : le résumé de fin de
        // séance s'affiche avant que SwiftData ait fini de nettoyer la relation.
        for item in Array(session.exercises) where item.sets.isEmpty {
            session.exercises.removeAll { $0.id == item.id }
            context.delete(item)
        }

        session.endedAt = .now
        session.date = session.startedAt

        if let activeRoutine, session.routineName == activeRoutine.name {
            activeRoutine.advanceCycle()
        }

        save()
        self.session = nil
        stopRest()
        Haptics.success()
        onFinish?(session)
    }

    func discard(reason: String? = nil) {
        if let session {
            context.delete(session)
            save()
        }
        session = nil
        stopRest()
        if let reason {
            toast = Toast(text: reason, kind: .warning)
        }
        Haptics.warning()
    }

    // MARK: - Édition des exercices

    @discardableResult
    func addExercise(
        _ exercise: Exercise,
        to session: WorkoutSession,
        defaultSets: Int = 3,
        defaultReps: Int = 10,
        history: [WorkoutSession] = [],
        copyLastPerformance: Bool = true
    ) -> WorkoutExercise {
        let item = WorkoutExercise(exercise: exercise, order: session.nextOrder())
        context.insert(item)
        session.attach(item)

        if copyLastPerformance, let previous = lastPerformed(exercise, in: history) {
            // Le meilleur point de départ en salle : ce qu'on a fait la dernière
            // fois. On n'a plus qu'à confirmer ou ajuster.
            for set in previous.workingSets.sorted(by: { $0.order < $1.order }) {
                let copy = SetEntry(order: item.nextOrder(), reps: set.reps, weight: set.weight)
                context.insert(copy)
                item.attach(copy)
            }
        } else {
            let weight = lastUsedWeight(exercise, in: history)
            for index in 0..<max(1, defaultSets) {
                let entry = SetEntry(order: index, reps: max(1, defaultReps), weight: weight)
                context.insert(entry)
                item.attach(entry)
            }
        }

        save()
        Haptics.tap()
        return item
    }

    func removeExercise(_ item: WorkoutExercise) {
        if let session = item.session {
            context.delete(item)
            renumber(session: session)
            save()
        }
        Haptics.warning()
    }

    /// Déplace un exercice d'un cran vers le haut ou le bas.
    func move(_ item: WorkoutExercise, by offset: Int, in session: WorkoutSession) {
        var ordered = session.orderedExercises
        guard let index = ordered.firstIndex(where: { $0.id == item.id }) else { return }
        let target = index + offset
        guard ordered.indices.contains(target) else { return }
        ordered.swapAt(index, target)
        for (position, element) in ordered.enumerated() {
            element.order = position
        }
        save()
        Haptics.tap()
    }

    func moveExercises(in session: WorkoutSession, from offsets: IndexSet, to destination: Int) {
        var ordered = session.orderedExercises
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, item) in ordered.enumerated() {
            item.order = index
        }
        save()
    }

    /// Remet les valeurs de la dernière fois sur un exercice déjà présent.
    func copyLastPerformance(into item: WorkoutExercise, history: [WorkoutSession]) {
        guard let exercise = item.exercise else { return }
        guard let previous = lastPerformed(exercise, in: history) else {
            toast = Toast(text: "Pas encore d'historique sur \(exercise.name)", kind: .warning)
            return
        }

        for set in item.sets {
            context.delete(set)
        }
        item.sets.removeAll()

        for set in previous.workingSets.sorted(by: { $0.order < $1.order }) {
            let copy = SetEntry(order: item.nextOrder(), reps: set.reps, weight: set.weight, rpe: set.rpe)
            context.insert(copy)
            item.attach(copy)
        }
        save()
        Haptics.success()
        toast = Toast(text: "Valeurs de \(previous.session?.date.shortDayLabel ?? "la dernière fois") recopiées", kind: .success)
    }

    // MARK: - Édition des séries

    @discardableResult
    func addSet(to item: WorkoutExercise, copyLast: Bool = true) -> SetEntry {
        let last = item.orderedSets.last
        let entry = SetEntry(
            order: item.nextOrder(),
            reps: copyLast ? (last?.reps ?? 10) : 10,
            weight: copyLast ? (last?.weight ?? 0) : 0
        )
        context.insert(entry)
        item.attach(entry)
        save()
        Haptics.tap()
        return entry
    }

    func removeSet(_ set: SetEntry) {
        let parent = set.workoutExercise
        context.delete(set)
        if let parent {
            renumber(sets: parent)
        }
        save()
        Haptics.warning()
    }

    func toggleWarmup(_ set: SetEntry) {
        set.isWarmup.toggle()
        save()
        Haptics.tap()
    }

    func markSetCompleted(_ set: SetEntry, exerciseName: String?) {
        save()
        startRest(exerciseName: exerciseName)
    }

    // MARK: - Aides internes

    private func lastPerformed(_ exercise: Exercise, in history: [WorkoutSession]) -> WorkoutExercise? {
        history
            .filter { !$0.isInProgress }
            .sorted { $0.date > $1.date }
            .compactMap { session in
                session.exercises.first { $0.exercise?.id == exercise.id && !$0.workingSets.isEmpty }
            }
            .first
    }

    private func lastUsedWeight(_ exercise: Exercise, in history: [WorkoutSession]) -> Double {
        lastPerformed(exercise, in: history)?.maxWeight ?? 0
    }

    private func renumber(session: WorkoutSession) {
        for (index, item) in session.orderedExercises.enumerated() {
            item.order = index
        }
    }

    private func renumber(sets item: WorkoutExercise) {
        for (index, set) in item.orderedSets.enumerated() {
            set.order = index
        }
    }
}
