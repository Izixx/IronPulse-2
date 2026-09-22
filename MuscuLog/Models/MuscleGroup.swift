import SwiftUI

/// Groupes musculaires suivis par l'application.
///
/// Le `rawValue` est la valeur réellement persistée dans SwiftData :
/// ne jamais renommer un cas existant sans migration.
enum MuscleGroup: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case pectoraux
    case dos
    case epaules
    case biceps
    case triceps
    case quadriceps
    case ischioJambiers
    case mollets
    case fessiers
    case abdominaux

    var id: String { rawValue }

    /// Nom affiché, tel qu'on l'écrit dans une salle de sport.
    var title: String {
        switch self {
        case .pectoraux: "Pectoraux"
        case .dos: "Dos"
        case .epaules: "Épaules"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .quadriceps: "Quadriceps"
        case .ischioJambiers: "Ischio-jambiers"
        case .mollets: "Mollets"
        case .fessiers: "Fessiers"
        case .abdominaux: "Abdominaux"
        }
    }

    /// Libellé court pour les axes de graphiques.
    var shortTitle: String {
        switch self {
        case .ischioJambiers: "Ischio"
        case .quadriceps: "Quads"
        case .pectoraux: "Pecs"
        case .abdominaux: "Abs"
        default: title
        }
    }

    var symbolName: String {
        switch self {
        case .pectoraux: "figure.strengthtraining.traditional"
        case .dos: "figure.rower"
        case .epaules: "figure.arms.open"
        case .biceps: "dumbbell.fill"
        case .triceps: "figure.strengthtraining.functional"
        case .quadriceps: "figure.run"
        case .ischioJambiers: "figure.step.training"
        case .mollets: "figure.walk"
        case .fessiers: "figure.cooldown"
        case .abdominaux: "figure.core.training"
        }
    }

    var tint: Color {
        switch self {
        case .pectoraux: .pink
        case .dos: .blue
        case .epaules: .orange
        case .biceps: .purple
        case .triceps: .indigo
        case .quadriceps: .red
        case .ischioJambiers: .brown
        case .mollets: .teal
        case .fessiers: .mint
        case .abdominaux: .yellow
        }
    }

    /// Délai de récupération conseillé avant de retravailler ce muscle.
    /// 72 h pour les gros groupes polyarticulaires, 48 h pour les petits.
    var recommendedRecoveryHours: Double {
        switch self {
        case .quadriceps, .ischioJambiers, .fessiers, .dos, .pectoraux: 72
        case .epaules, .biceps, .triceps, .mollets, .abdominaux: 48
        }
    }

    var recommendedRecoveryDays: Double { recommendedRecoveryHours / 24 }

    /// Ordre canonique d'affichage (haut du corps → bas → gainage).
    var sortIndex: Int {
        MuscleGroup.allCases.firstIndex(of: self) ?? 0
    }
}
