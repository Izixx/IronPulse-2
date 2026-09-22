import Foundation

/// Export complet des données locales.
///
/// Indispensable en sideload : avec un Apple ID gratuit la signature expire au
/// bout de 7 jours et la réinstallation peut effacer le conteneur de l'app.
/// Un export régulier est la seule sauvegarde fiable.
enum ExportService {

    /// Version du format d'export. À incrémenter si la structure du JSON change,
    /// pour qu'un futur import sache à quoi il a affaire.
    static let formatVersion = "1"

    // MARK: - DTO (jamais les modèles SwiftData directement)

    struct Payload: Codable {
        var app: String
        var version: String
        var exportedAt: Date
        var exercises: [ExerciseDTO]
        var sessions: [SessionDTO]
        var routines: [RoutineDTO]
        var bodyWeights: [BodyWeightDTO]
    }

    struct ExerciseDTO: Codable {
        var id: UUID
        var name: String
        var muscleGroups: [String]
        var equipment: String?
        var isCustom: Bool
    }

    struct SessionDTO: Codable {
        var id: UUID
        var date: Date
        var startedAt: Date
        var endedAt: Date?
        var note: String?
        var routineName: String?
        var routineDayName: String?
        var totalVolume: Double
        var exercises: [SessionExerciseDTO]
    }

    struct SessionExerciseDTO: Codable {
        var id: UUID
        var exerciseName: String
        var muscleGroups: [String]
        var sets: [SetDTO]
    }

    struct SetDTO: Codable {
        var order: Int
        var reps: Int
        var weightKg: Double
        var rpe: Double?
        var isWarmup: Bool
        var estimated1RM: Double
    }

    struct RoutineDTO: Codable {
        var id: UUID
        var name: String
        var isActive: Bool
        var nextDayIndex: Int
        var days: [RoutineDayDTO]
    }

    struct RoutineDayDTO: Codable {
        var name: String
        var order: Int
        var exercises: [RoutineDayExerciseDTO]
    }

    struct RoutineDayExerciseDTO: Codable {
        var exerciseName: String
        var targetSets: Int
        var targetReps: Int
    }

    struct BodyWeightDTO: Codable {
        var date: Date
        var kilograms: Double
        var note: String?
    }

    // MARK: - Construction

    static func makePayload(
        sessions: [WorkoutSession],
        exercises: [Exercise],
        routines: [Routine],
        bodyWeights: [BodyWeightEntry]
    ) -> Payload {
        Payload(
            app: "MuscuLog",
            version: formatVersion,
            exportedAt: .now,
            exercises: exercises.map { exercise in
                ExerciseDTO(
                    id: exercise.id,
                    name: exercise.name,
                    muscleGroups: exercise.muscleGroups.map(\.title),
                    equipment: exercise.equipment,
                    isCustom: exercise.isCustom
                )
            },
            sessions: sessions.map { session in
                SessionDTO(
                    id: session.id,
                    date: session.date,
                    startedAt: session.startedAt,
                    endedAt: session.endedAt,
                    note: session.note,
                    routineName: session.routineName,
                    routineDayName: session.routineDayName,
                    totalVolume: session.totalVolume,
                    exercises: session.orderedExercises.map { item in
                        SessionExerciseDTO(
                            id: item.id,
                            exerciseName: item.displayName,
                            muscleGroups: item.muscleGroups.map(\.title),
                            sets: item.orderedSets.map { set in
                                SetDTO(
                                    order: set.order,
                                    reps: set.reps,
                                    weightKg: set.weight,
                                    rpe: set.rpe,
                                    isWarmup: set.isWarmup,
                                    estimated1RM: set.estimated1RM
                                )
                            }
                        )
                    }
                )
            },
            routines: routines.map { routine in
                RoutineDTO(
                    id: routine.id,
                    name: routine.name,
                    isActive: routine.isActive,
                    nextDayIndex: routine.nextDayIndex,
                    days: routine.orderedDays.map { day in
                        RoutineDayDTO(
                            name: day.name,
                            order: day.order,
                            exercises: day.orderedExercises.map { item in
                                RoutineDayExerciseDTO(
                                    exerciseName: item.displayName,
                                    targetSets: item.targetSets,
                                    targetReps: item.targetReps
                                )
                            }
                        )
                    }
                )
            },
            bodyWeights: bodyWeights.map { entry in
                BodyWeightDTO(date: entry.date, kilograms: entry.kilograms, note: entry.note)
            }
        )
    }

    // MARK: - JSON

    static func jsonData(for payload: Payload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    // MARK: - CSV

    static let csvHeader = [
        "date", "heure", "seance", "exercice", "groupes_musculaires",
        "numero_serie", "repetitions", "poids_kg", "rpe", "echauffement", "volume_kg", "1rm_estime_kg"
    ].joined(separator: ";")

    static func csv(for sessions: [WorkoutSession]) -> String {
        var lines = [csvHeader]

        for session in sessions.sorted(by: { $0.date < $1.date }) {
            let day = session.date.formatted(.iso8601.year().month().day())
            let time = session.date.formatted(date: .omitted, time: .shortened)
            for item in session.orderedExercises {
                let groups = item.muscleGroups.map(\.title).joined(separator: ", ")
                for set in item.orderedSets {
                    let fields: [String] = [
                        day,
                        time,
                        session.title,
                        item.displayName,
                        groups,
                        String(set.order + 1),
                        String(set.reps),
                        trimmed(set.weight),
                        set.rpe.map(trimmed) ?? "",
                        set.isWarmup ? "oui" : "non",
                        trimmed(set.volume),
                        trimmed(set.estimated1RM)
                    ]
                    lines.append(fields.map(escape).joined(separator: ";"))
                }
            }
        }

        // BOM UTF-8 : sans lui, Excel français massacrerait les accents.
        return "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
    }

    private static func trimmed(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(";") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - Écriture sur disque (pour ShareLink)

    static func write(_ data: Data, fileExtension: String) throws -> URL {
        let stamp = Date.now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MuscuLog-\(stamp).\(fileExtension)")
        try data.write(to: url, options: .atomic)
        return url
    }
}
