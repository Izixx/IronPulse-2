import SwiftData
import XCTest

@testable import MuscuLog

/// Tests des formules, du formatage et de l'export — la partie « filet de
/// sécurité » : si l'export casse, l'utilisateur peut perdre ses données au
/// bout des 7 jours de signature Sideloadly.
@MainActor
final class ExportAndFormattingTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Exercise.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            SetEntry.self,
            Routine.self,
            RoutineDay.self,
            RoutineDayExercise.self,
            BodyWeightEntry.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return container.mainContext
    }

    private func makeSampleSession(_ context: ModelContext) -> WorkoutSession {
        let exercise = Exercise(name: "Développé couché", muscleGroups: [.pectoraux, .triceps], equipment: "Barre")
        context.insert(exercise)

        let session = WorkoutSession(date: Date(timeIntervalSince1970: 1_700_000_000), note: "Bonne forme")
        session.endedAt = session.startedAt.addingTimeInterval(3_600)
        context.insert(session)

        let item = WorkoutExercise(exercise: exercise, order: 0)
        context.insert(item)
        session.attach(item)

        let warmup = SetEntry(order: 0, reps: 10, weight: 40, isWarmup: true)
        context.insert(warmup)
        item.attach(warmup)

        let working = SetEntry(order: 1, reps: 5, weight: 100, rpe: 8)
        context.insert(working)
        item.attach(working)

        return session
    }

    // MARK: - 1RM

    func testEpleyFormula() {
        XCTAssertEqual(OneRepMax.estimate(weight: 100, reps: 1), 100, accuracy: 0.001)
        XCTAssertEqual(OneRepMax.estimate(weight: 100, reps: 5), 116.666, accuracy: 0.01)
        XCTAssertEqual(OneRepMax.estimate(weight: 60, reps: 10), 80, accuracy: 0.01)
    }

    func testOneRepMaxHandlesDegenerateInput() {
        XCTAssertEqual(OneRepMax.estimate(weight: 0, reps: 5), 0)
        XCTAssertEqual(OneRepMax.estimate(weight: 100, reps: 0), 0)
        XCTAssertEqual(OneRepMax.estimate(weight: -50, reps: 5), 0)
    }

    func testWeightForRepsIsInverseOfEstimate() {
        let oneRM = OneRepMax.estimate(weight: 100, reps: 5)
        XCTAssertEqual(OneRepMax.weight(forReps: 5, from: oneRM), 100, accuracy: 0.01)
        XCTAssertLessThan(OneRepMax.weight(forReps: 1, from: oneRM), oneRM)
        XCTAssertGreaterThan(OneRepMax.weight(forReps: 10, from: oneRM), 0)
    }

    // MARK: - Formatage

    func testNumberFormatting() {
        XCTAssertEqual(80.0.cleanWeight, "80")
        XCTAssertEqual(82.5.cleanWeight.hasPrefix("82"), true)
        XCTAssertEqual(1_500.0.volumeInTonnes.hasPrefix("1"), true)
        XCTAssertEqual(DurationFormatter.countdown(90), "1:30")
        XCTAssertEqual(DurationFormatter.countdown(-5), "0:00")
        XCTAssertEqual(DurationFormatter.workout(3_600), "1 h 00")
        XCTAssertEqual(DurationFormatter.workout(2_700), "45 min")
    }

    func testSearchIgnoresAccents() {
        let exercise = Exercise(name: "Développé couché", muscleGroups: [.pectoraux], equipment: "Barre")

        XCTAssertTrue(exercise.matches(searchText: "developpe"))
        XCTAssertTrue(exercise.matches(searchText: "COUCHE"))
        XCTAssertTrue(exercise.matches(searchText: "barre"))
        XCTAssertTrue(exercise.matches(searchText: "pecto"))
        XCTAssertTrue(exercise.matches(searchText: ""))
        XCTAssertFalse(exercise.matches(searchText: "squat"))
    }

    func testMuscleGroupStorageRoundTrip() {
        let exercise = Exercise(name: "Squat", muscleGroups: [.quadriceps, .fessiers])
        XCTAssertEqual(exercise.muscleGroupsRaw, ["quadriceps", "fessiers"])
        XCTAssertEqual(exercise.muscleGroups, [.quadriceps, .fessiers])
        XCTAssertEqual(exercise.primaryMuscleGroup, .quadriceps)
    }

    // MARK: - Export

    func testCSVExport() throws {
        let context = try makeContext()
        let session = makeSampleSession(context)

        let csv = ExportService.csv(for: [session])

        XCTAssertTrue(csv.hasPrefix("\u{FEFF}"), "BOM UTF-8 attendu pour Excel")
        XCTAssertTrue(csv.contains("date;heure;seance;exercice"))
        XCTAssertTrue(csv.contains("Développé couché"))
        XCTAssertTrue(csv.contains("Pectoraux, Triceps"))
        XCTAssertTrue(csv.contains(";100;8;non;500;116.7"))

        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 3, "En-tête + 2 séries")
        // La ligne d'échauffement est marquée comme telle mais reste exportée.
        XCTAssertTrue(csv.contains(";oui;400;"))
    }

    func testCSVEscapesSemicolonsInFields() throws {
        let context = try makeContext()

        let exercise = Exercise(name: "Curl; bizarre", muscleGroups: [.biceps])
        context.insert(exercise)
        let session = WorkoutSession()
        context.insert(session)
        let item = WorkoutExercise(exercise: exercise, order: 0)
        context.insert(item)
        session.attach(item)
        let set = SetEntry(order: 0, reps: 10, weight: 20)
        context.insert(set)
        item.attach(set)

        let csv = ExportService.csv(for: [session])
        XCTAssertTrue(csv.contains("\"Curl; bizarre\""))
    }

    func testJSONExportRoundTrip() throws {
        let context = try makeContext()
        let session = makeSampleSession(context)
        let exercise = try XCTUnwrap(session.orderedExercises.first?.exercise)

        let payload = ExportService.makePayload(
            sessions: [session],
            exercises: [exercise],
            routines: [],
            bodyWeights: [BodyWeightEntry(date: .now, kilograms: 78.4)]
        )

        let data = try ExportService.jsonData(for: payload)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportService.Payload.self, from: data)

        XCTAssertEqual(decoded.app, "MuscuLog")
        XCTAssertEqual(decoded.sessions.count, 1)
        XCTAssertEqual(decoded.bodyWeights.first?.kilograms, 78.4)
        XCTAssertEqual(decoded.exercises.first?.name, "Développé couché")
        XCTAssertEqual(decoded.exercises.first?.muscleGroups, ["Pectoraux", "Triceps"])

        let sessionDTO = try XCTUnwrap(decoded.sessions.first)
        XCTAssertEqual(sessionDTO.totalVolume, 500, accuracy: 0.001)
        XCTAssertEqual(sessionDTO.exercises.first?.sets.count, 2)
        XCTAssertEqual(sessionDTO.exercises.first?.sets.last?.estimated1RM ?? 0, 116.666, accuracy: 0.01)
    }

    func testPayloadExportsRoutines() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Squat", muscleGroups: [.quadriceps])
        context.insert(exercise)

        let routine = Routine(name: "PPL", isActive: true)
        context.insert(routine)
        let day = RoutineDay(name: "Legs", order: 0)
        context.insert(day)
        routine.attach(day)
        let line = RoutineDayExercise(exercise: exercise, order: 0, targetSets: 4, targetReps: 6)
        context.insert(line)
        day.attach(line)

        let payload = ExportService.makePayload(
            sessions: [],
            exercises: [exercise],
            routines: [routine],
            bodyWeights: []
        )

        XCTAssertEqual(payload.routines.first?.name, "PPL")
        XCTAssertEqual(payload.routines.first?.isActive, true)
        XCTAssertEqual(payload.routines.first?.days.first?.exercises.first?.targetSets, 4)
    }
}
