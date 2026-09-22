import SwiftData
import SwiftUI

/// Détail d'un exercice : records personnels, courbe de progression et
/// historique des séances où il apparaît.
struct ExerciseDetailView: View {

    let exercise: Exercise

    @Environment(StatsViewModel.self) private var stats
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\WorkoutSession.date, order: .reverse)])
    private var sessions: [WorkoutSession]

    @State private var metric: ProgressMetric = .estimated1RM
    @State private var range: StatsRange = .all
    @State private var isEditing = false
    @State private var isArchiveAlertPresented = false

    private var records: ExerciseRecords {
        stats.records(for: exercise, in: sessions)
    }

    private var points: [ExerciseProgressPoint] {
        let all = stats.progress(for: exercise, in: sessions)
        guard let start = range.startDate else { return all }
        return all.filter { $0.date >= start }
    }

    /// Séances où l'exercice a été travaillé, de la plus récente à la plus ancienne.
    private var performedSessions: [WorkoutSession] {
        sessions.filter { session in
            !session.isInProgress && session.exercises.contains { $0.exercise?.id == exercise.id }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerCard
                recordsCard
                progressCard
                historyCard
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Modifier", systemImage: "pencil") { isEditing = true }
                    Button("Archiver", systemImage: "archivebox", role: .destructive) {
                        isArchiveAlertPresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            ExerciseEditView(exercise: exercise)
        }
        .alert("Archiver cet exercice ?", isPresented: $isArchiveAlertPresented) {
            Button("Annuler", role: .cancel) {}
            Button("Archiver", role: .destructive) {
                exercise.isArchived = true
                try? context.save()
            }
        } message: {
            Text("Il disparaîtra des listes mais l'historique des séances reste intact.")
        }
    }

    // MARK: - Cartes

    private var headerCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 5) {
                    ForEach(exercise.muscleGroups) { group in
                        MuscleTag(group: group)
                    }
                }
                if let equipment = exercise.equipment {
                    Label(equipment, systemImage: "hammer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 14) {
                    Label(
                        records.lastPerformed.map { "Dernière fois : \($0.shortDayLabel)" } ?? "Jamais réalisé",
                        systemImage: "clock.arrow.circlepath"
                    )
                    Label("\(records.timesPerformed) séance(s)", systemImage: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var recordsCard: some View {
        Card(title: "Records personnels", systemImage: "trophy.fill") {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                StatTile(
                    title: "Charge max",
                    value: records.bestWeight.cleanWeight,
                    unit: "kg",
                    subtitle: records.bestWeightDate.map { "\(records.bestWeightReps) reps · \($0.shortDayLabel)" },
                    systemImage: "scalemass.fill",
                    tint: .red
                )
                StatTile(
                    title: "1RM estimé",
                    value: records.bestEstimated1RM.cleanWeight,
                    unit: "kg",
                    subtitle: records.bestEstimated1RMDate.map { "Epley · \($0.shortDayLabel)" },
                    systemImage: "chart.line.uptrend.xyaxis",
                    tint: .orange
                )
                StatTile(
                    title: "Meilleur volume",
                    value: records.bestVolumeInSession.cleanVolume,
                    unit: "kg",
                    subtitle: records.bestVolumeDate.map { "en une séance · \($0.shortDayLabel)" },
                    systemImage: "square.stack.3d.up.fill",
                    tint: .teal
                )
                StatTile(
                    title: "Charge conseillée",
                    value: records.suggestedWorkingWeight.cleanWeight,
                    unit: "kg",
                    subtitle: "pour viser 8 répétitions",
                    systemImage: "target",
                    tint: .purple
                )
            }
        }
    }

    private var progressCard: some View {
        Card(title: "Progression", systemImage: "chart.xyaxis.line") {
            VStack(alignment: .leading, spacing: 12) {
                RangePicker(range: $range)

                Picker("Métrique", selection: $metric) {
                    ForEach(ProgressMetric.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if points.count < 2 {
                    EmptyStateView(
                        title: "Pas encore de courbe",
                        message: "Il faut au moins deux séances avec cet exercice pour tracer une progression.",
                        systemImage: "chart.line.downtrend.xyaxis"
                    )
                } else {
                    ExerciseProgressChart(points: points, metric: metric)

                    let values = points.map { metric.value($0) }
                    let first = values.first ?? 0
                    let last = values.last ?? 0
                    let delta = last - first
                    HStack(spacing: 12) {
                        Text("\(metric.title) : \(first.cleanWeight) → \(last.cleanWeight) \(metric.unit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text((delta >= 0 ? "+" : "") + delta.cleanWeight + " \(metric.unit)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(delta >= 0 ? .green : .red)
                    }
                }
            }
        }
    }

    private var historyCard: some View {
        Card(title: "Historique", systemImage: "clock") {
            if performedSessions.isEmpty {
                Text("Aucune séance enregistrée avec cet exercice.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(performedSessions.prefix(12)) { session in
                        let items = session.exercises.filter { $0.exercise?.id == exercise.id }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(session.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text("\(items.reduce(0) { $0 + $1.volume }.cleanVolume) kg")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Text(items.flatMap(\.orderedSets).map(\.summary).joined(separator: "  ·  "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if session.id != performedSessions.prefix(12).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}
