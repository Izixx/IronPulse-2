import SwiftData
import SwiftUI

/// Statistiques détaillées : équilibre musculaire, progression par exercice,
/// records, assiduité et analyses automatiques.
struct StatsDetailView: View {

    @Environment(StatsViewModel.self) private var stats

    @Query(sort: [SortDescriptor(\WorkoutSession.date, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query(
        filter: #Predicate<Exercise> { $0.isArchived == false },
        sort: [SortDescriptor(\Exercise.name)]
    )
    private var exercises: [Exercise]

    private var periodSessions: [WorkoutSession] {
        stats.filteredSessions(from: sessions)
    }

    private var volumes: [MuscleVolumeStat] {
        stats.muscleVolumes(periodSessions)
    }

    private var totals: GlobalTotals {
        stats.totals(periodSessions, allSessions: sessions, range: stats.range)
    }

    /// Exercices réellement travaillés, avec leurs records.
    private var trackedExercises: [TrackedExercise] {
        exercises
            .compactMap { exercise in
                let records = stats.records(for: exercise, in: sessions)
                return records.hasData ? TrackedExercise(exercise: exercise, records: records) : nil
            }
            .sorted { lhs, rhs in
                (lhs.records.lastPerformed ?? .distantPast) > (rhs.records.lastPerformed ?? .distantPast)
            }
    }

    var body: some View {
        @Bindable var stats = stats

        ScrollView {
            VStack(spacing: 14) {
                RangePicker(range: $stats.range)
                    .padding(.horizontal, 2)

                totalsCard
                balanceCard
                insightsCard
                progressListCard
                recordsCard
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Statistiques")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Cartes

    private var totalsCard: some View {
        let current = totals

        return Card(title: "Vue d'ensemble", systemImage: "chart.bar.fill") {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                StatTile(
                    title: "Séances",
                    value: current.sessionCount.cleanInt,
                    subtitle: "\(current.sessionsPerWeek.formatted(.number.precision(.fractionLength(1)))) par semaine",
                    systemImage: "calendar",
                    tint: .blue
                )
                StatTile(
                    title: "Volume total",
                    value: current.totalVolume.volumeInTonnes,
                    unit: "t",
                    subtitle: "\(current.averageVolumePerSession.volumeInTonnes) t / séance",
                    systemImage: "scalemass.fill",
                    tint: .teal
                )
                StatTile(
                    title: "Séries",
                    value: current.totalWorkingSets.cleanInt,
                    subtitle: "\(current.totalReps.cleanInt) répétitions",
                    systemImage: "square.stack.3d.up.fill",
                    tint: .orange
                )
                StatTile(
                    title: "Durée moyenne",
                    value: current.averageDuration.map { DurationFormatter.workout($0) } ?? "—",
                    subtitle: "\(current.currentStreakWeeks) sem. consécutives",
                    systemImage: "clock",
                    tint: .purple
                )
            }
        }
    }

    private var balanceCard: some View {
        Card(title: "Équilibre musculaire", systemImage: "figure.strengthtraining.traditional") {
            VStack(alignment: .leading, spacing: 16) {
                if volumes.allSatisfy({ $0.volume == 0 }) {
                    EmptyStateView(
                        title: "Pas encore de volume",
                        message: "Enregistre des séries pour analyser ton équilibre musculaire.",
                        systemImage: "chart.bar"
                    )
                } else {
                    MuscleShareChart(stats: volumes)
                    Divider()
                    Text("Tonnage par muscle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    MuscleBalanceChart(stats: volumes)
                    Divider()
                    MuscleRankingList(stats: volumes)
                    Divider()
                    Text("Séries par muscle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    setsGrid
                }
            }
        }
    }

    private var setsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 6)],
            alignment: .leading,
            spacing: 6
        ) {
            ForEach(stats.setsShare(periodSessions)) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.group.tint)
                        .frame(width: 8, height: 8)
                    Text(item.group.title)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text("\(item.sets)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var insightsCard: some View {
        Card(title: "Analyse", systemImage: "lightbulb.fill") {
            VStack(alignment: .leading, spacing: 10) {
                if insights.isEmpty {
                    Text("Encore trop peu de données pour tirer des conclusions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                            Text(insight)
                                .font(.footnote)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var progressListCard: some View {
        Card(title: "Progression par exercice", systemImage: "chart.xyaxis.line") {
            if trackedExercises.isEmpty {
                Text("Aucun exercice travaillé pour l'instant.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(trackedExercises.prefix(10))) { entry in
                        NavigationLink {
                            ExerciseDetailView(exercise: entry.exercise)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.exercise.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("Max \(entry.records.bestWeight.cleanWeight) kg · 1RM \(entry.records.bestEstimated1RM.cleanWeight) kg")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                trendBadge(for: entry.exercise)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)

                        if entry.exercise.id != trackedExercises.prefix(10).last?.exercise.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func trendBadge(for exercise: Exercise) -> some View {
        let points = stats.progress(for: exercise, in: sessions)
        let recent = points.suffix(4)
        let delta: Double
        if recent.count >= 2, let first = recent.first, let last = recent.last {
            delta = last.estimated1RM - first.estimated1RM
        } else {
            delta = 0
        }

        let positive = delta >= 0
        return Text((positive ? "+" : "") + delta.cleanWeight + " kg")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background((positive ? Color.green : Color.red).opacity(0.15), in: .capsule)
            .foregroundStyle(positive ? .green : .red)
    }

    private var recordsCard: some View {
        Card(title: "Records personnels", systemImage: "trophy.fill") {
            if trackedExercises.isEmpty {
                Text("Les records apparaîtront après tes premières séries.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(trackedExercises.prefix(12))) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: entry.exercise.primaryMuscleGroup?.symbolName ?? "dumbbell")
                                .font(.caption)
                                .frame(width: 18)
                                .foregroundStyle(entry.exercise.primaryMuscleGroup?.tint ?? .accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.exercise.name)
                                    .font(.subheadline.weight(.medium))
                                Text("Meilleur volume : \(entry.records.bestVolumeInSession.cleanVolume) kg"
                                     + (entry.records.bestVolumeDate.map { " (\($0.shortDayLabel))" } ?? ""))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 4)

                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(entry.records.bestWeight.cleanWeight) kg")
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                Text("1RM ≈ \(entry.records.bestEstimated1RM.cleanWeight) kg")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Analyse automatique

    private var insights: [String] {
        var result: [String] = []
        let ready = stats.musclesReadyToTrain(allSessions: sessions)
        let current = totals

        let worked = volumes.filter { $0.volume > 0 }.sorted { $0.volume > $1.volume }
        if let first = worked.first, let last = worked.last, worked.count > 1, last.volume > 0 {
            let ratio = first.volume / last.volume
            if ratio >= 2.5 {
                result.append(
                    "Déséquilibre marqué : \(first.group.title) reçoit \(ratio.formatted(.number.precision(.fractionLength(0...1))))× plus de tonnage que \(last.group.title). Ajoute une série ou deux sur le muscle en retard."
                )
            }
        }

        let never = volumes.filter { $0.volume == 0 && $0.workingSets == 0 }.map(\.group)
        if !never.isEmpty {
            result.append(
                "Jamais travaillé sur la période : \(never.map(\.title).joined(separator: ", "))."
            )
        }

        if let overdue = ready.first {
            result.append(
                "\(overdue.group.title) est prêt depuis \(overdue.wholeDaysSince ?? 0) jour(s) : c'est le meilleur candidat pour la prochaine séance."
            )
        }

        if current.sessionCount > 1 {
            let frequency = current.sessionsPerWeek
            if frequency < 2 {
                result.append("Fréquence actuelle : \(frequency.formatted(.number.precision(.fractionLength(1)))) séance(s) par semaine. 3 séances/semaine équilibrent mieux la récupération et le volume.")
            } else if frequency > 6 {
                result.append("\(frequency.formatted(.number.precision(.fractionLength(1)))) séances par semaine : pense à surveiller le sommeil et les signes de fatigue.")
            }
        }

        if let duration = current.averageDuration, duration > 100 * 60 {
            result.append("Tes séances durent en moyenne \(DurationFormatter.workout(duration)) : au-delà de 90 minutes la qualité des dernières séries baisse souvent.")
        }

        return result
    }
}
