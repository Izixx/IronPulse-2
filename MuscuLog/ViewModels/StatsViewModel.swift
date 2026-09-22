import Foundation
import SwiftUI

/// Moteur de statistiques de l'app.
///
/// Toutes les fonctions sont **pures** : elles reçoivent les séances et
/// renvoient des valeurs simples. Cela permet de les tester sans interface et
/// de garder les vues minces.
///
/// Conventions importantes :
/// - Les séries d'échauffement sont exclues de tous les calculs.
/// - Le volume d'un exercice est réparti **à parts égales** entre ses groupes
///   musculaires : un développé couché (pectoraux + triceps + épaules) donne
///   1/3 de son tonnage à chacun. La somme des volumes par muscle est donc
///   égale au volume total, ce qui rend le camembert honnête.
@Observable
@MainActor
final class StatsViewModel {

    var range: StatsRange = .month

    private let calendar = Calendar.current

    // MARK: - Filtrage

    func sessions(in range: StatsRange, from all: [WorkoutSession]) -> [WorkoutSession] {
        let done = all.filter { !$0.isInProgress }
        guard let start = range.startDate else { return done }
        return done.filter { $0.date >= start }
    }

    func filteredSessions(from all: [WorkoutSession]) -> [WorkoutSession] {
        sessions(in: range, from: all)
    }

    // MARK: - Volume par groupe musculaire

    func muscleVolumes(_ sessions: [WorkoutSession]) -> [MuscleVolumeStat] {
        var volume: [MuscleGroup: Double] = [:]
        var sets: [MuscleGroup: Int] = [:]
        var sessionIDs: [MuscleGroup: Set<UUID>] = [:]

        for session in sessions {
            for item in session.orderedExercises {
                let groups = item.muscleGroups
                guard !groups.isEmpty else { continue }
                let share = 1.0 / Double(groups.count)
                for group in groups {
                    volume[group, default: 0] += item.volume * share
                    sets[group, default: 0] += item.workingSetCount
                    sessionIDs[group, default: []].insert(session.id)
                }
            }
        }

        return MuscleGroup.allCases.map { group in
            MuscleVolumeStat(
                group: group,
                volume: volume[group] ?? 0,
                workingSets: sets[group] ?? 0,
                sessionCount: sessionIDs[group]?.count ?? 0
            )
        }
    }

    /// Groupes triés du plus travaillé au moins travaillé (pour le camembert
    /// et le classement « équilibre »).
    func rankedMuscleVolumes(_ sessions: [WorkoutSession]) -> [MuscleVolumeStat] {
        muscleVolumes(sessions).sorted { $0.volume > $1.volume }
    }

    // MARK: - Récupération / quoi entraîner

    /// Pour chaque groupe musculaire : depuis quand il n'a pas été sollicité.
    /// On analyse **tout** l'historique, pas seulement la période filtrée.
    func recoveryStats(allSessions: [WorkoutSession]) -> [MuscleRecoveryStat] {
        var lastTrained: [MuscleGroup: Date] = [:]
        var setsLast7: [MuscleGroup: Int] = [:]
        var volumeLast7: [MuscleGroup: Double] = [:]
        var totalSets: [MuscleGroup: Int] = [:]

        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date.now.startOfDay) ?? .distantPast

        for session in allSessions {
            for item in session.orderedExercises {
                let groups = item.muscleGroups
                guard !groups.isEmpty else { continue }
                let share = 1.0 / Double(groups.count)
                let isRecent = session.date >= cutoff

                for group in groups {
                    totalSets[group, default: 0] += item.workingSetCount
                    if let current = lastTrained[group] {
                        if session.date > current { lastTrained[group] = session.date }
                    } else {
                        lastTrained[group] = session.date
                    }
                    if isRecent {
                        setsLast7[group, default: 0] += item.workingSetCount
                        volumeLast7[group, default: 0] += item.volume * share
                    }
                }
            }
        }

        return MuscleGroup.allCases.map { group in
            MuscleRecoveryStat(
                group: group,
                lastTrained: lastTrained[group],
                workingSetsLast7Days: setsLast7[group] ?? 0,
                volumeLast7Days: volumeLast7[group] ?? 0,
                totalWorkingSets: totalSets[group] ?? 0
            )
        }
    }

    /// Muscles prêts à être retravaillés, du plus urgent au moins urgent.
    func musclesReadyToTrain(allSessions: [WorkoutSession]) -> [MuscleRecoveryStat] {
        recoveryStats(allSessions: allSessions)
            .filter(\.isSuggestedToday)
            .sorted { $0.priorityScore > $1.priorityScore }
    }

    // MARK: - « Quoi entraîner aujourd'hui ? »

    func suggestion(allSessions: [WorkoutSession], activeRoutine: Routine?) -> SessionSuggestion {
        let stats = recoveryStats(allSessions: allSessions)
        let byGroup = Dictionary(uniqueKeysWithValues: stats.map { ($0.group, $0) })
        let ready = stats.filter(\.isSuggestedToday).sorted { $0.priorityScore > $1.priorityScore }

        // Une routine active pilote le cycle : c'est elle qui décide du jour.
        if let routine = activeRoutine, let day = routine.nextDay, !day.exercises.isEmpty {
            let groups = day.muscleGroups.compactMap { byGroup[$0] }
            return SessionSuggestion(
                groups: groups,
                routineName: routine.name,
                routineDayName: day.name,
                routineDayIndex: day.order,
                headline: day.name,
                rationale: "Cycle \(routine.name) — prochaine séance prévue : \(day.name) (\(day.orderedExercises.count) exercices)."
            )
        }

        let top = Array(ready.prefix(4))
        if top.isEmpty {
            return SessionSuggestion(
                groups: [],
                routineName: nil,
                routineDayName: nil,
                routineDayIndex: nil,
                headline: "Récupération",
                rationale: "Tous les groupes musculaires sont encore en récupération. Repos ou séance très légère : c'est là qu'on progresse.",
                allRecovering: true
            )
        }

        let names = top.map(\.group.title).joined(separator: ", ")
        return SessionSuggestion(
            groups: top,
            routineName: nil,
            routineDayName: nil,
            routineDayIndex: nil,
            headline: names,
            rationale: "Ces muscles n'ont pas été travaillés depuis le délai de récupération conseillé. De quoi équilibrer la semaine."
        )
    }

    // MARK: - Statistiques globales

    func totals(_ sessions: [WorkoutSession], allSessions: [WorkoutSession], range: StatsRange) -> GlobalTotals {
        var totals = GlobalTotals()
        let done = sessions
        totals.sessionCount = done.count
        totals.totalVolume = done.reduce(0) { $0 + $1.totalVolume }
        totals.totalWorkingSets = done.reduce(0) { $0 + $1.totalSets }
        totals.totalReps = done.reduce(0) { $0 + $1.totalReps }

        let durations = done.compactMap(\.duration).filter { $0 > 60 }
        if !durations.isEmpty {
            totals.averageDuration = durations.reduce(0, +) / Double(durations.count)
        }
        if totals.sessionCount > 0 {
            totals.averageVolumePerSession = totals.totalVolume / Double(totals.sessionCount)
        }

        // Fréquence : sur la période choisie, ou depuis la première séance.
        let days: Int
        if range == .all {
            let first = (allSessions.filter { !$0.isInProgress }.map(\.date).min()) ?? .now
            days = max(7, calendar.dateComponents([.day], from: first.startOfDay, to: Date.now.startOfDay).day ?? 7)
        } else {
            days = range.dayCount
        }
        totals.sessionsPerWeek = Double(totals.sessionCount) / (Double(days) / 7.0)

        let ranked = rankedMuscleVolumes(done).filter { $0.volume > 0 }
        totals.busiestMuscle = ranked.first
        totals.quietestMuscle = ranked.last

        totals.currentStreakDays = streakDays(allSessions)
        totals.currentStreakWeeks = streakWeeks(allSessions)
        return totals
    }

    private func streakDays(_ sessions: [WorkoutSession]) -> Int {
        let days = Set(sessions.filter { !$0.isInProgress }.map { $0.date.startOfDay })
        guard !days.isEmpty else { return 0 }

        var cursor = Date.now.startOfDay
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private func streakWeeks(_ sessions: [WorkoutSession]) -> Int {
        let weeks = Set(
            sessions
                .filter { !$0.isInProgress }
                .compactMap { calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start }
        )
        guard !weeks.isEmpty else { return 0 }

        guard var cursor = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        if !weeks.contains(cursor) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = previous
        }
        var streak = 0
        while weeks.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    // MARK: - Progression par exercice

    func progress(for exercise: Exercise, in sessions: [WorkoutSession]) -> [ExerciseProgressPoint] {
        sessions
            .filter { !$0.isInProgress }
            .sorted { $0.date < $1.date }
            .compactMap { session -> ExerciseProgressPoint? in
                let items = session.exercises.filter { $0.exercise?.id == exercise.id }
                guard !items.isEmpty else { return nil }
                return ExerciseProgressPoint(
                    id: session.id,
                    date: session.date,
                    maxWeight: items.map(\.maxWeight).max() ?? 0,
                    estimated1RM: items.map(\.estimated1RM).max() ?? 0,
                    volume: items.reduce(0) { $0 + $1.volume },
                    topReps: items.map(\.topReps).max() ?? 0
                )
            }
    }

    func records(for exercise: Exercise, in sessions: [WorkoutSession]) -> ExerciseRecords {
        var records = ExerciseRecords()
        var bestWeight = 0.0
        var best1RM = 0.0
        var bestVolume = 0.0
        var bestReps = 0

        for session in sessions where !session.isInProgress {
            let items = session.exercises.filter { $0.exercise?.id == exercise.id }
            guard !items.isEmpty else { continue }

            records.timesPerformed += 1
            if records.lastPerformed == nil || session.date > records.lastPerformed! {
                records.lastPerformed = session.date
            }

            let sessionVolume = items.reduce(0) { $0 + $1.volume }
            if sessionVolume > bestVolume {
                bestVolume = sessionVolume
                records.bestVolumeInSession = sessionVolume
                records.bestVolumeDate = session.date
            }

            for item in items {
                for set in item.workingSets {
                    if set.weight > bestWeight {
                        bestWeight = set.weight
                        records.bestWeight = set.weight
                        records.bestWeightDate = session.date
                        records.bestWeightReps = set.reps
                    }
                    let oneRM = set.estimated1RM
                    if oneRM > best1RM {
                        best1RM = oneRM
                        records.bestEstimated1RM = oneRM
                        records.bestEstimated1RMDate = session.date
                    }
                    if set.reps > bestReps {
                        bestReps = set.reps
                        records.bestReps = set.reps
                        records.bestRepsWeight = set.weight
                    }
                }
            }
        }

        if best1RM > 0 {
            // Charge de travail conseillée : ~8 répétitions, arrondie à 2,5 kg
            // (plus petite galette dispo dans la plupart des salles).
            let target = OneRepMax.weight(forReps: 8, from: best1RM)
            records.suggestedWorkingWeight = (target / 2.5).rounded() * 2.5
        }
        return records
    }

    /// Charge réellement utilisée la dernière fois, pour préremplir la séance.
    func lastPerformedEntry(for exercise: Exercise, in sessions: [WorkoutSession]) -> WorkoutExercise? {
        sessions
            .filter { !$0.isInProgress }
            .sorted { $0.date > $1.date }
            .compactMap { session in
                session.exercises
                    .filter { $0.exercise?.id == exercise.id && !$0.workingSets.isEmpty }
                    .first
            }
            .first
    }

    // MARK: - Heatmap d'assiduité

    func heatmap(_ sessions: [WorkoutSession], weeks: Int = 26) -> [HeatmapWeek] {
        let counts = Dictionary(grouping: sessions.filter { !$0.isInProgress }) { $0.date.startOfDay }
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }

        var result: [HeatmapWeek] = []
        for offset in stride(from: weeks - 1, through: 0, by: -1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart) else { continue }
            var days: [HeatmapDay] = []
            for dayOffset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                let daySessions = counts[day] ?? []
                days.append(
                    HeatmapDay(
                        id: day,
                        date: day,
                        sessionCount: daySessions.count,
                        volume: daySessions.reduce(0) { $0 + $1.totalVolume }
                    )
                )
            }
            result.append(HeatmapWeek(id: weekStart, startDate: weekStart, days: days))
        }
        return result
    }

    // MARK: - Aide au diagnostic

    /// Nombre total de séries par muscle sur la période : pratique pour
    /// repérer un déséquilibre que le tonnage seul ne montre pas.
    func setsShare(_ sessions: [WorkoutSession]) -> [MuscleSetShare] {
        muscleVolumes(sessions)
            .filter { $0.workingSets > 0 }
            .sorted { $0.workingSets > $1.workingSets }
            .map { MuscleSetShare(group: $0.group, sets: $0.workingSets) }
    }
}
