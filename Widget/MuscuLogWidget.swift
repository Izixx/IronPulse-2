import SwiftUI
import WidgetKit

// NOTE : cette cible n'est PAS construite par défaut (voir project.yml).
// Un widget d'écran d'accueil exige un App Group partagé, donc un compte
// développeur Apple payant — impossible avec un Apple ID gratuit, et une
// extension non signable ferait échouer l'installation Sideloadly.

struct MuscuLogEntry: TimelineEntry {
    let date: Date
    let headline: String
    let detail: String
    let muscles: [String]
    let sessionsLast7Days: Int
    let volumeLast7Days: Double
    let streakWeeks: Int

    static let placeholder = MuscuLogEntry(
        date: .now,
        headline: "Push",
        detail: "Routine active : Push / Pull / Legs",
        muscles: ["Pectoraux", "Triceps", "Épaules"],
        sessionsLast7Days: 3,
        volumeLast7Days: 12_400,
        streakWeeks: 5
    )

    static func from(_ payload: WidgetSnapshot.Payload, at date: Date) -> MuscuLogEntry {
        MuscuLogEntry(
            date: date,
            headline: payload.headline,
            detail: payload.detail,
            muscles: payload.muscles,
            sessionsLast7Days: payload.sessionsLast7Days,
            volumeLast7Days: payload.volumeLast7Days,
            streakWeeks: payload.streakWeeks
        )
    }
}

struct MuscuLogProvider: TimelineProvider {

    func placeholder(in context: Context) -> MuscuLogEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (MuscuLogEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MuscuLogEntry>) -> Void) {
        let entry = currentEntry()
        // Rafraîchissement horaire : les notifications de l'app déclenchent en
        // plus un reload immédiat quand une séance est terminée.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3_600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> MuscuLogEntry {
        guard let payload = WidgetSnapshot.load() else { return .placeholder }
        return MuscuLogEntry.from(payload, at: .now)
    }
}

struct MuscuLogWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: MuscuLogEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        default:
            mediumView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Aujourd'hui")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(entry.headline)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                StatBadge(value: "\(entry.sessionsLast7Days)", label: "7 j")
                StatBadge(value: "\(entry.streakWeeks)", label: "sem.")
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("MuscuLog", systemImage: "figure.strengthtraining.traditional")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(entry.streakWeeks) sem. d'affilée")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(entry.headline)
                .font(.title3.weight(.bold))
                .lineLimit(1)

            if !entry.muscles.isEmpty {
                HStack(spacing: 4) {
                    ForEach(entry.muscles.prefix(4), id: \.self) { muscle in
                        Text(muscle)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.16), in: .capsule)
                    }
                }
            }

            Text(entry.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                StatBadge(value: "\(entry.sessionsLast7Days)", label: "séances / 7 j")
                StatBadge(value: entry.volumeLast7Days.volumeInTonnes, label: "tonnes / 7 j")
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

private struct StatBadge: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct MuscuLogWidget: Widget {
    let kind = "MuscuLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MuscuLogProvider()) { entry in
            MuscuLogWidgetView(entry: entry)
        }
        .configurationDisplayName("Séance du jour")
        .description("Prochaine séance suggérée et statistiques rapides.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct MuscuLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        MuscuLogWidget()
    }
}
