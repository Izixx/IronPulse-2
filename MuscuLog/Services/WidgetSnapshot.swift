import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

/// Instantané léger partagé avec l'extension Widget.
///
/// Le widget ne lit **jamais** la base SwiftData directement : deux processus
/// qui ouvrent le même fichier de base, c'est le meilleur moyen de la corrompre.
/// L'app écrit ici un petit JSON, le widget le lit. C'est la méthode classique
/// et sûre.
///
/// L'écriture se fait dans le conteneur partagé « App Group », qui exige un
/// compte développeur payant. Sans entitlement, `UserDefaults(suiteName:)`
/// écrit simplement dans un domaine isolé et le widget reste vide : aucune
/// erreur, aucun crash.
enum WidgetSnapshot {

    struct Payload: Codable {
        var generatedAt: Date
        var headline: String
        var detail: String
        var muscles: [String]
        var sessionsLast7Days: Int
        var volumeLast7Days: Double
        var streakWeeks: Int
        var lastSessionTitle: String?
        var lastSessionDate: Date?
    }

    static let appGroupIdentifier = "group.com.example.musculog"
    private static let storageKey = "musculog.widget.snapshot"

    // MARK: - Écriture (app)

    @MainActor
    static func refresh(sessions: [WorkoutSession], routines: [Routine]) {
        let stats = StatsViewModel()
        let completed = sessions.filter { !$0.isInProgress }
        let suggestion = stats.suggestion(
            allSessions: completed,
            activeRoutine: routines.first { $0.isActive }
        )

        let last7 = stats.sessions(in: .week, from: sessions)
        let totals = stats.totals(last7, allSessions: sessions, range: .week)
        let last = completed.max { $0.date < $1.date }

        let payload = Payload(
            generatedAt: .now,
            headline: suggestion.routineDayName.map { $0 } ?? suggestion.headline,
            detail: suggestion.rationale,
            muscles: suggestion.groups.map(\.group.title),
            sessionsLast7Days: totals.sessionCount,
            volumeLast7Days: totals.totalVolume,
            streakWeeks: totals.currentStreakWeeks,
            lastSessionTitle: last?.title,
            lastSessionDate: last?.date
        )

        save(payload)
    }

    static func save(_ payload: Payload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults?.set(data, forKey: storageKey)
    }

    // MARK: - Lecture (widget)

    static func load() -> Payload? {
        guard
            let data = defaults?.data(forKey: storageKey),
            let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }
        return payload
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
}

/// Demande au système de redessiner les widgets. Inoffensif si aucun widget
/// n'est installé.
enum WidgetBridge {
    static func reload() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
