import SwiftData
import SwiftUI

/// Onglet Historique : toutes les séances, groupées par mois, avec la heatmap
/// d'assiduité en tête. Chaque séance reste modifiable après coup.
struct HistoryView: View {

    @Environment(\.modelContext) private var context
    @Environment(StatsViewModel.self) private var stats

    @Query(sort: [SortDescriptor(\WorkoutSession.date, order: .reverse)])
    private var sessions: [WorkoutSession]

    @State private var searchText = ""
    @State private var showsHeatmap = true

    private var completed: [WorkoutSession] {
        sessions.filter { !$0.isInProgress }
    }

    private var totals: GlobalTotals {
        stats.totals(completed, allSessions: sessions, range: .all)
    }

    private var filtered: [WorkoutSession] {
        let needle = searchText.foldedForSearch
        guard !needle.isEmpty else { return completed }
        return completed.filter { session in
            session.title.foldedForSearch.contains(needle)
                || session.orderedExercises.contains { $0.displayName.foldedForSearch.contains(needle) }
        }
    }

    private var grouped: [SessionMonthGroup] {
        Dictionary(grouping: filtered) { $0.date.monthLabel }
            .map { SessionMonthGroup(month: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { ($0.items.first?.date ?? .distantPast) > ($1.items.first?.date ?? .distantPast) }
    }

    var body: some View {
        List {
            if showsHeatmap {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        AttendanceHeatmap(weeks: stats.heatmap(sessions, weeks: 26))
                        HStack(spacing: 14) {
                            Label("\(totals.sessionCount) séances", systemImage: "calendar")
                            Label("\(totals.totalVolume.volumeInTonnes) t", systemImage: "scalemass")
                            Label("\(totals.sessionsPerWeek.formatted(.number.precision(.fractionLength(1)))) /sem.", systemImage: "speedometer")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    HStack {
                        Text("Assiduité").textCase(nil)
                        Spacer()
                        Button(showsHeatmap ? "Masquer" : "Afficher") {
                            withAnimation(.snappy) { showsHeatmap.toggle() }
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                }
            } else {
                Section {
                    Button("Afficher la heatmap d'assiduité") {
                        withAnimation(.snappy) { showsHeatmap = true }
                    }
                    .font(.subheadline)
                }
            }

            if completed.isEmpty {
                Section {
                    EmptyStateView(
                        title: "Aucune séance",
                        message: "Tes séances terminées apparaîtront ici, avec la possibilité de les modifier.",
                        systemImage: "calendar.badge.plus"
                    )
                    .listRowBackground(Color.clear)
                }
            }

            ForEach(grouped) { section in
                Section {
                    ForEach(section.items) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            sessionRow(session)
                        }
                    }
                    .onDelete { offsets in
                        delete(offsets, in: section.items)
                    }
                } header: {
                    HStack {
                        Text(section.month).textCase(nil)
                        Spacer()
                        Text("\(section.items.count) séance(s) · \(section.items.reduce(0) { $0 + $1.totalVolume }.volumeInTonnes) t")
                            .textCase(nil)
                            .font(.caption)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Rechercher une séance ou un exercice")
        .navigationTitle("Historique")
        .navigationBarTitleDisplayMode(.large)
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(session.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.subheadline.weight(.semibold))
                Text(session.title)
                    .font(.caption)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.14), in: .capsule)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text("\(session.totalVolume.volumeInTonnes) t")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Label("\(session.orderedExercises.count) exercices", systemImage: "list.bullet")
                Label("\(session.totalSets) séries", systemImage: "square.stack.3d.up")
                if let duration = session.duration {
                    Label(DurationFormatter.workout(duration), systemImage: "clock")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(Array(session.muscleGroups.sorted { $0.sortIndex < $1.sortIndex })) { group in
                    MuscleTag(group: group, compact: true)
                }
            }

            if let note = session.note, !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 3)
    }

    private func delete(_ offsets: IndexSet, in items: [WorkoutSession]) {
        for index in offsets where items.indices.contains(index) {
            context.delete(items[index])
        }
        try? context.save()
        Haptics.warning()
    }
}
