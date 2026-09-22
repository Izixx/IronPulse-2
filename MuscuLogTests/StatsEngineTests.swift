import SwiftData
import XCTest

@testable import MuscuLog

/// Tests du moteur de statistiques.
///
/// Ils tournent sur simulateur dans la CI (`xcodebuild test`) : c'est la seule
/// vérification automatique possible tant que le projet est développé sous
/// Windows, sans Mac. Toute la logique métier est donc testée ici.
@MainActor
final class StatsEngineTests: XCTestCase {

    // MARK: - Harnais

    /// Conteneur partagé (voir `TestStore`) : recréer un conteneur en mémoire
    /// par test fait planter l'hôte de test sur iOS 26.
    private func makeContext() throws -> ModelContext {
        try TestStore.makeContext()
    }

    private func makeExercise(
        _ context: ModelContext,
        _ name: String,
        _ groups: [MuscleGroup],
        equipment: String? = nil
    ) -> Exercise {
        let exercise = Exercise(name: name, muscleGroups: groups, equipment: equipment, isCustom: false)
        context.insert(exercise)
        return exercise
    }

    @discardableResult
    private func makeSession(
        _ context: ModelContext,
        daysAgo: Int,
        routineName: String? = nil,
        routineDayName: String? = nil
    ) -> WorkoutSession {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let session = WorkoutSession(
            date: date,
            routineName: routineName,
            routineDayName: routineDayName
        )
        session.endedAt = date.addingTimeInterval(3_600)
        context.insert(session)
        return session
    }

    @discardableResult
    private func addExercise(
        _ context: ModelContext,
        to session: WorkoutSession,
        _ exercise: Exercise
    ) -> WorkoutExercise {
        let item = WorkoutExercise(exercise: exercise, order: session.nextOrder())
        context.insert(item)
        session.attach(item)
        return item
    }

    private func addSet(
        _ context: ModelContext,
        to item: WorkoutExercise,
        reps: Int,
        weight: Double,
        warmup: Bool = false
    ) {
        let entry = SetEntry(order: item.nextOrder(), reps: reps, weight: weight, isWarmup: warmup)
        context.insert(entry)
        item.attach(entry)
    }

    // MARK: - Relations

    func testRelationshipAttachmentKeepsBothSidesInSync() throws {
        let context = try makeContext()
        let exercise = makeExercise(context, "Squat", [.quadriceps])
        let session = makeSession(context, daysAgo: 0)
        let item = addExercise(context, to: session, exercise)
        addSet(context, to: item, reps: 5, weight: 100)

        XCTAssertEqual(session.exercises.count, 1)
        XCTAssertEqual(item.sets.count, 1)
        XCTAssertEqual(session.orderedExercises.first?.displayName, "Squat")
        XCTAssertEqual(item.sets.first?.workoutExercise?.id, item.id)
    }

    // MARK: - Volume

    func testWarmupSetsAreExcludedFromVolume() throws {
        let context = try makeContext()
        let exercise = makeExercise(context, "Développé couché", [.pectoraux])
        let session = makeSession(context, daysAgo: 0)
        let item = addExercise(context, to: session, exercise)

        addSet(context, to: item, reps: 10, weight: 40, warmup: true)
        addSet(context, to: item, reps: 5, weight: 100)

        XCTAssertEqual(item.volume, 500, accuracy: 0.001)
        XCTAssertEqual(item.workingSetCount, 1)
        XCTAssertEqual(session.totalVolume, 500, accuracy: 0.001)
        XCTAssertEqual(session.totalSets, 1)
    }

    func testVolumeIsSplitEvenlyAcrossMuscleGroups() throws {
        let context = try makeContext()
        let stats = StatsViewModel()

        let bench = makeExercise(context, "Développé couché", [.pectoraux, .triceps])
        let session = makeSession(context, daysAgo: 0)
        let item = addExercise(context, to: session, bench)
        addSet(context, to: item, reps: 10, weight: 100)

        let volumes = stats.muscleVolumes([session])
        let chest = try XCTUnwrap(volumes.first { $0.group == .pectoraux })
        let triceps = try XCTUnwrap(volumes.first { $0.group == .triceps })

        XCTAssertEqual(chest.volume, 500, accuracy: 0.001)
        XCTAssertEqual(triceps.volume, 500, accuracy: 0.001)

        // La somme des volumes par muscle doit égaler le volume total :
        // c'est ce qui rend le camembert honnête.
        let total = volumes.reduce(0) { $0 + $1.volume }
        XCTAssertEqual(total, session.totalVolume, accuracy: 0.001)
    }

    func testMuscleVolumesCoverEveryGroup() throws {
        let context = try makeContext()
        let stats = StatsViewModel()

        // Un seul groupe travaillé : les autres doivent malgré tout apparaître,
        // à zéro, sinon le camembert et le bilan d'équilibre mentiraient.
        let squat = makeExercise(context, "Squat", [.quadriceps])
        let session = makeSession(context, daysAgo: 0)
        addSet(context, to: addExercise(context, to: session, squat), reps: 5, weight: 100)

        let volumes = stats.muscleVolumes([session])

        XCTAssertEqual(volumes.count, MuscleGroup.allCases.count)
        XCTAssertEqual(volumes.first { $0.group == .quadriceps }?.volume ?? 0, 500, accuracy: 0.001)
        XCTAssertTrue(
            volumes.filter { $0.group != .quadriceps }
                .allSatisfy { $0.volume == 0 && $0.workingSets == 0 }
        )
        XCTAssertEqual(volumes.reduce(0) { $0 + $1.volume }, session.totalVolume, accuracy: 0.001)
    }

    // MARK: - Récupération et suggestion

    func testRecoveryStates() throws {
        let context = try makeContext()
        let stats = StatsViewModel()

        let chest = makeExercise(context, "Développé couché", [.pectoraux])
        let recent = makeSession(context, daysAgo: 1)
        addSet(context, to: addExercise(context, to: recent, chest), reps: 8, weight: 80)

        let oldSession = makeSession(context, daysAgo: 8)
        let squat = makeExercise(context, "Squat", [.quadriceps])
        addSet(context, to: addExercise(context, to: oldSession, squat), reps: 5, weight: 120)

        let recovery = stats.recoveryStats(allSessions: [recent, oldSession])

        let chestStat = try XCTUnwrap(recovery.first { $0.group == .pectoraux })
        XCTAssertEqual(chestStat.state, .recovering)
        XCTAssertFalse(chestStat.isSuggestedToday)

        let quadStat = try XCTUnwrap(recovery.first { $0.group == .quadriceps })
        XCTAssertEqual(quadStat.state, .overdue)
        XCTAssertTrue(quadStat.isSuggestedToday)

        let neverTrained = try XCTUnwrap(recovery.first { $0.group == .mollets })
        XCTAssertEqual(neverTrained.state, .never)
        XCTAssertEqual(neverTrained.priorityScore, 1_000)
    }

    func testSuggestionPutsTheMostOverdueMuscleFirst() throws {
        let context = try makeContext()
        let stats = StatsViewModel()

        let chest = makeExercise(context, "Développé couché", [.pectoraux])
        let legs = makeExercise(context, "Squat", [.quadriceps])

        let recent = makeSession(context, daysAgo: 0)
        addSet(context, to: addExercise(context, to: recent, legs), reps: 5, weight: 120)

        let older = makeSession(context, daysAgo: 10)
        addSet(context, to: addExercise(context, to: older, chest), reps: 8, weight: 80)

        let suggestion = stats.suggestion(allSessions: [recent, older], activeRoutine: nil)
        XCTAssertEqual(suggestion.groups.first?.group, .pectoraux)
        XCTAssertFalse(suggestion.allRecovering)
    }

    func testSuggestionFollowsActiveRoutineCycle() throws {
        let context = try makeContext()
        let stats = StatsViewModel()

        let bench = makeExercise(context, "Développé couché", [.pectoraux])
        let routine = Routine(name: "PPL", isActive: true)
        context.insert(routine)

        let push = RoutineDay(name: "Push", order: 0)
        context.insert(push)
        routine.attach(push)
        let line = RoutineDayExercise(exercise: bench, order: 0, targetSets: 4, targetReps: 8)
        context.insert(line)
        push.attach(line)

        let pull = RoutineDay(name: "Pull", order: 1)
        context.insert(pull)
        routine.attach(pull)

        let suggestion = stats.suggestion(allSessions: [], activeRoutine: routine)
        XCTAssertEqual(suggestion.routineDayName, "Push")
        XCTAssertEqual(suggestion.groups.first?.group, .pectoraux)

        routine.advanceCycle()
        XCTAssertEqual(routine.nextDay?.name, "Pull")
        routine.advanceCycle()
        XCTAssertEqual(routine.nextDay?.name, "Push", "Le cycle doit boucler")
    }

    func testAllRecoveringSuggestionHasNoGroups() throws {
        let context = try makeContext()
        let stats = StatsViewModel()

        // Tous les groupes travaillés aujourd'hui : rien à proposer.
        let session = makeSession(context, daysAgo: 0)
        for group in MuscleGroup.allCases {
            let exercise = makeExercise(context, "Exercice \(group.title)", [group])
            addSet(context, to: addExercise(context, to: session, exercise), reps: 10, weight: 20)
        }

        let suggestion = stats.suggestion(allSessions: [session], activeRoutine: nil)
        XCTAssertTrue(suggestion.groups.isEmpty)
        XCTAssertTrue(suggestion.allRecovering)
    }

    // MARK: - Records et progression

    func testRecordsAreComputedOnWorkingSets() throws {
        let context = try makeContext()
        let stats = StatsViewModel()
        let exercise = makeExercise(context, "Développé couché", [.pectoraux])

        let first = makeSession(context, daysAgo: 10)
        let firstItem = addExercise(context, to: first, exercise)
        addSet(context, to: firstItem, reps: 10, weight: 60, warmup: true)
        addSet(context, to: firstItem, reps: 5, weight: 100)

        let second = makeSession(context, daysAgo: 3)
        let secondItem = addExercise(context, to: second, exercise)
        addSet(context, to: secondItem, reps: 3, weight: 110)
        addSet(context, to: secondItem, reps: 8, weight: 80)

        let records = stats.records(for: exercise, in: [first, second])

        XCTAssertEqual(records.timesPerformed, 2)
        XCTAssertEqual(records.bestWeight, 110, accuracy: 0.001)
        XCTAssertEqual(records.bestWeightReps, 3)
        XCTAssertEqual(records.bestEstimated1RM, 121, accuracy: 0.01)
        // Meilleur volume *sur une séance* : 3 × 110 + 8 × 80 = 970 (la série
        // d'échauffement ne compte pas).
        XCTAssertEqual(records.bestVolumeInSession, 970, accuracy: 0.001)
        XCTAssertEqual(records.bestVolumeDate.map { Calendar.current.isDate($0, inSameDayAs: second.date) }, true)
        XCTAssertEqual(records.bestReps, 8)
        XCTAssertEqual(records.suggestedWorkingWeight, 95, accuracy: 0.001)
        XCTAssertTrue(records.hasData)
    }

    func testProgressSeriesIsSortedChronologically() throws {
        let context = try makeContext()
        let stats = StatsViewModel()
        let exercise = makeExercise(context, "Squat", [.quadriceps])

        for (daysAgo, weight) in [(20, 80.0), (10, 90.0), (2, 100.0)] {
            let session = makeSession(context, daysAgo: daysAgo)
            addSet(context, to: addExercise(context, to: session, exercise), reps: 5, weight: weight)
        }

        let points = stats.progress(for: exercise, in: [makeSession(context, daysAgo: 0)])
        XCTAssertTrue(points.isEmpty, "Les séances sans cet exercice ne doivent pas produire de point")

        let allPoints = stats.progress(for: exercise, in: try context.fetch(FetchDescriptor<WorkoutSession>()))
        XCTAssertEqual(allPoints.count, 3)
        XCTAssertEqual(allPoints.map(\.maxWeight), [80, 90, 100])
        XCTAssertEqual(allPoints.map(\.date), allPoints.map(\.date).sorted())
    }

    func testLastPerformedEntryIgnoresTheRequestedSession() throws {
        let context = try makeContext()
        let stats = StatsViewModel()
        let exercise = makeExercise(context, "Squat", [.quadriceps])

        let old = makeSession(context, daysAgo: 10)
        let oldItem = addExercise(context, to: old, exercise)
        addSet(context, to: oldItem, reps: 5, weight: 90)

        let recent = makeSession(context, daysAgo: 1)
        let recentItem = addExercise(context, to: recent, exercise)
        addSet(context, to: recentItem, reps: 5, weight: 110)

        let found = stats.lastPerformedEntry(for: exercise, in: [old, recent])
        XCTAssertEqual(found?.maxWeight, 110)
    }

    // MARK: - Statistiques globales

    func testTotalsAndStreaks() throws {
        let context = try makeContext()
        let stats = StatsViewModel()
        let exercise = makeExercise(context, "Squat", [.quadriceps])

        for daysAgo in [0, 1, 2] {
            let session = makeSession(context, daysAgo: daysAgo)
            addSet(context, to: addExercise(context, to: session, exercise), reps: 5, weight: 100)
        }

        let all = try context.fetch(FetchDescriptor<WorkoutSession>())
        let totals = stats.totals(all, allSessions: all, range: .all)

        XCTAssertEqual(totals.sessionCount, 3)
        XCTAssertEqual(totals.totalVolume, 1_500, accuracy: 0.001)
        XCTAssertEqual(totals.totalWorkingSets, 3)
        XCTAssertEqual(totals.currentStreakDays, 3)
        XCTAssertEqual(totals.busiestMuscle?.group, .quadriceps)
    }

    func testInProgressSessionsAreExcluded() throws {
        let context = try makeContext()
        let stats = StatsViewModel()
        let exercise = makeExercise(context, "Squat", [.quadriceps])

        let finished = makeSession(context, daysAgo: 1)
        addSet(context, to: addExercise(context, to: finished, exercise), reps: 5, weight: 100)

        let running = WorkoutSession()
        context.insert(running)
        addSet(context, to: addExercise(context, to: running, exercise), reps: 5, weight: 100)

        let all = try context.fetch(FetchDescriptor<WorkoutSession>())
        let filtered = stats.sessions(in: .all, from: all)

        XCTAssertEqual(filtered.count, 1)
        XCTAssertTrue(filtered.allSatisfy { !$0.isInProgress })
    }

    // MARK: - Heatmap

    func testHeatmapShapeAndLevels() throws {
        let context = try makeContext()
        let stats = StatsViewModel()
        let exercise = makeExercise(context, "Squat", [.quadriceps])

        let today = makeSession(context, daysAgo: 0)
        addSet(context, to: addExercise(context, to: today, exercise), reps: 5, weight: 100)

        let weeks = stats.heatmap([today], weeks: 4)
        XCTAssertEqual(weeks.count, 4)
        XCTAssertTrue(weeks.allSatisfy { $0.days.count == 7 })

        let lastWeek = try XCTUnwrap(weeks.last)
        let todayCell = try XCTUnwrap(lastWeek.days.first { Calendar.current.isDateInToday($0.date) })
        XCTAssertEqual(todayCell.sessionCount, 1)
        XCTAssertEqual(todayCell.level, 1)
        XCTAssertEqual(todayCell.volume, 500, accuracy: 0.001)
    }

    func testHeatmapLevelsScaleWithSessionCount() {
        XCTAssertEqual(HeatmapScale.level(for: 0), 0)
        XCTAssertEqual(HeatmapScale.level(for: 1), 1)
        XCTAssertEqual(HeatmapScale.level(for: 2), 2)
        XCTAssertEqual(HeatmapScale.level(for: 3), 3)
        XCTAssertEqual(HeatmapScale.level(for: 9), 4)
    }
}
