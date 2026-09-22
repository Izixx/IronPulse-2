import Foundation

// MARK: - Période analysée

/// Filtre temporel commun à toutes les statistiques.
enum StatsRange: String, CaseIterable, Identifiable, Codable {
    case week
    case month
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "7 jours"
        case .month: "30 jours"
        case .all: "Depuis le début"
        }
    }

    /// Date de début, ou `nil` pour « depuis le début ».
    var startDate: Date? {
        switch self {
        case .week: Calendar.current.date(byAdding: .day, value: -6, to: Date.now.startOfDay)
        case .month: Calendar.current.date(byAdding: .day, value: -29, to: Date.now.startOfDay)
        case .all: nil
        }
    }

    /// Nombre de jours couverts, pour les moyennes.
    var dayCount: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .all: 0
        }
    }
}

// MARK: - Volume par muscle

struct MuscleVolumeStat: Identifiable, Hashable {
    let group: MuscleGroup
    var volume: Double
    var workingSets: Int
    var sessionCount: Int

    var id: String { group.rawValue }

    func share(of total: Double) -> Double {
        total > 0 ? volume / total : 0
    }
}

// MARK: - Récupération

enum RecoveryState: String {
    /// Jamais entraîné depuis l'installation de l'app.
    case never
    /// Délai de récupération non écoulé.
    case recovering
    /// Prêt à être retravaillé, mais récemment.
    case ready
    /// Oublié depuis longtemps : à prioriser.
    case overdue

    var title: String {
        switch self {
        case .never: "Jamais travaillé"
        case .recovering: "En récupération"
        case .ready: "Prêt"
        case .overdue: "À travailler"
        }
    }
}

struct MuscleRecoveryStat: Identifiable, Hashable {
    let group: MuscleGroup
    var lastTrained: Date?
    var workingSetsLast7Days: Int
    var volumeLast7Days: Double
    var totalWorkingSets: Int

    var id: String { group.rawValue }

    var daysSince: Double? {
        lastTrained?.daysSinceDouble
    }

    /// Nombre de jours entiers écoulés depuis la dernière sollicitation.
    var wholeDaysSince: Int? {
        lastTrained?.daysSince
    }

    var requiredDays: Double { group.recommendedRecoveryDays }

    var state: RecoveryState {
        guard let daysSince else { return .never }
        if daysSince < requiredDays { return .recovering }
        if daysSince < requiredDays * 2 { return .ready }
        return .overdue
    }

    /// Score de priorité : plus il est élevé, plus le muscle mérite la séance
    /// du jour. Un muscle jamais travaillé passe devant tout le reste, un
    /// muscle encore en récupération obtient un score négatif (donc écarté).
    var priorityScore: Double {
        guard let daysSince else { return 1_000 }
        let overdue = daysSince - requiredDays
        if overdue < 0 { return -requiredDays + daysSince - 10 }
        // Bonus progressif pour éviter de toujours proposer les 2 mêmes muscles.
        return overdue
    }

    var isSuggestedToday: Bool { state == .never || state == .overdue || state == .ready }

    var lastTrainedLabel: String {
        guard let lastTrained else { return "Jamais" }
        let days = lastTrained.daysSince
        switch days {
        case 0: return "Aujourd'hui"
        case 1: return "Hier"
        case 2...: return "Il y a \(days) jours"
        default: return lastTrained.shortDayLabel
        }
    }
}

// MARK: - Statistiques globales

struct GlobalTotals {
    var sessionCount: Int = 0
    var totalVolume: Double = 0
    var totalWorkingSets: Int = 0
    var totalReps: Int = 0
    var averageDuration: TimeInterval?
    var sessionsPerWeek: Double = 0
    var averageVolumePerSession: Double = 0
    var busiestMuscle: MuscleVolumeStat?
    var quietestMuscle: MuscleVolumeStat?
    /// Jours consécutifs terminés par « au moins une séance », en remontant
    /// depuis aujourd'hui (ou hier).
    var currentStreakDays: Int = 0
    /// Semaines consécutives avec au moins une séance.
    var currentStreakWeeks: Int = 0
}

// MARK: - Progression par exercice

struct ExerciseProgressPoint: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let maxWeight: Double
    let estimated1RM: Double
    let volume: Double
    let topReps: Int
}

struct ExerciseRecords {
    var bestWeight: Double = 0
    var bestWeightDate: Date?
    var bestWeightReps: Int = 0
    var bestEstimated1RM: Double = 0
    var bestEstimated1RMDate: Date?
    var bestVolumeInSession: Double = 0
    var bestVolumeDate: Date?
    var bestReps: Int = 0
    var bestRepsWeight: Double = 0
    var timesPerformed: Int = 0
    var lastPerformed: Date?
    /// Charge conseillée pour la prochaine séance, calculée sur le meilleur
    /// 1RM estimé (utile pour progresser sans se cramer).
    var suggestedWorkingWeight: Double = 0

    var hasData: Bool { timesPerformed > 0 }

    /// Un nouveau record battrait-il ces valeurs ?
    func wouldBeat(weight: Double, reps: Int) -> Bool {
        let oneRM = OneRepMax.estimate(weight: weight, reps: reps)
        return weight > bestWeight || oneRM > bestEstimated1RM
    }
}

// MARK: - Heatmap d'assiduité

struct HeatmapDay: Identifiable, Hashable {
    let id: Date
    let date: Date
    let sessionCount: Int
    let volume: Double

    var level: Int { HeatmapScale.level(for: sessionCount) }
}

struct HeatmapWeek: Identifiable, Hashable {
    let id: Date
    let startDate: Date
    let days: [HeatmapDay]
}

// MARK: - Regroupements d'affichage

// Ces types existent parce que SwiftUI ne sait pas identifier une collection
// de tuples (une key path ne peut pas viser un élément de tuple) : on préfère
// des structures nommées.

struct MuscleSetShare: Identifiable, Hashable {
    let group: MuscleGroup
    let sets: Int
    var id: String { group.rawValue }
}

struct MuscleExerciseGroup: Identifiable {
    let group: MuscleGroup
    let items: [Exercise]
    var id: String { group.rawValue }
}

struct SessionMonthGroup: Identifiable {
    let month: String
    let items: [WorkoutSession]
    var id: String { month }
}

struct TrackedExercise: Identifiable {
    let exercise: Exercise
    let records: ExerciseRecords
    var id: UUID { exercise.id }
}

// MARK: - Suggestion de séance

struct SessionSuggestion {
    /// Muscles à prioriser aujourd'hui, du plus urgent au moins urgent.
    var groups: [MuscleRecoveryStat]
    /// Renseignés quand la suggestion vient d'une routine active.
    var routineName: String?
    var routineDayName: String?
    var routineDayIndex: Int?
    var headline: String
    var rationale: String
    /// `true` si tous les muscles sont encore en récupération : dans ce cas
    /// on suggère une séance légère plutôt qu'un vrai entraînement.
    var allRecovering: Bool = false

    var isEmpty: Bool { groups.isEmpty }
}
