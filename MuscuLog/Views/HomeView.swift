import SwiftData
import SwiftUI

/// Onglet Accueil : tout ce qu'il faut savoir en un coup d'œil, et surtout
/// la réponse à « qu'est-ce que je fais aujourd'hui ? ».
struct HomeView: View {

    @Binding var selectedTab: AppTab

    @Environment(StatsViewModel.self) private var stats
    @Environment(ActiveSessionViewModel.self) private var sessionVM

    @Query(sort: [SortDescriptor(\WorkoutSession.date, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query(sort: [SortDescriptor(\Routine.createdAt)])
    private var routines: [Routine]

    @Query(
        filter: #Predicate<Exercise> { $0.isArchived == false },
        sort: [SortDescriptor(\Exercise.name)]
    )
    private var exercises: [Exercise]

    @Query(sort: [SortDescriptor(\BodyWeightEntry.date, order: .reverse)])
    private var bodyWeights: [BodyWeightEntry]

    // MARK: - Données dérivées

    private var completedSessions: [WorkoutSession] {
        sessions.filter { !$0.isInProgress }
    }

    private var activeRoutine: Routine? {
        routines.first { $0.isActive }
    }

    private var suggestion: SessionSuggestion {
        stats.suggestion(allSessions: completedSessions, activeRoutine: activeRoutine)
    }

    private var totals: GlobalTotals {
        stats.totals(
            stats.filteredSessions(from: sessions),
            allSessions: sessions,
            range: stats.range
        )
    }

    private var periodVolumes: [MuscleVolumeStat] {
        stats.muscleVolumes(stats.filteredSessions(from: sessions))
    }

    // MARK: - Corps

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if sessionVM.session != nil {
                    BigActionButton(
                        title: "Reprendre la séance en cours",
                        systemImage: "play.circle.fill",
                        tint: .green,
                        subtitle: sessionVM.session.map {
                            "\($0.exercises.count) exercices · \($0.totalSets) séries"
                        }
                    ) {
                        selectedTab = .session
                    }
                }

                if completedSessions.isEmpty {
                    welcomeCard
                } else {
                    suggestionCard
                    quickStatsCard
                    balanceCard
                    heatmapCard
                }

                linksCard
            }
            .padding(16)
            .padding(.bottom, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Aujourd'hui")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }

    // MARK: - Cartes

    private var welcomeCard: some View {
        Card(title: "Bienvenue", systemImage: "hand.wave.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Trois étapes, et c'est parti.")
                    .font(.headline)
                bullet("1", "Démarre une séance depuis l'onglet Séance.")
                bullet("2", "Ajoute des exercices : les valeurs de la dernière fois sont recopiées automatiquement, tu n'as plus qu'à confirmer.")
                bullet("3", "Reviens ici : volume par muscle, records et courbes se remplissent tout seuls.")
                Button {
                    selectedTab = .session
                } label: {
                    Label("Démarrer ma première séance", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private func bullet(_ index: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(index)
                .font(.caption.weight(.bold))
                .frame(width: 18, height: 18)
                .background(Color.accentColor.opacity(0.18), in: .circle)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var suggestionCard: some View {
        let current = suggestion

        return Card(title: "Quoi entraîner aujourd'hui ?", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                Text(current.headline)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(current.rationale)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !current.groups.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(Array(current.groups.prefix(5))) { stat in
                            recoveryRow(stat)
                        }
                    }
                }

                Button {
                    startSuggestion(current)
                } label: {
                    Label(
                        current.routineDayName.map { "Lancer : \($0)" } ?? "Démarrer cette séance",
                        systemImage: "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(current.allRecovering)
            }
        }
    }

    private func recoveryRow(_ stat: MuscleRecoveryStat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: stat.group.symbolName)
                .font(.footnote)
                .frame(width: 20)
                .foregroundStyle(stat.group.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(stat.group.title)
                    .font(.subheadline.weight(.medium))
                Text(stat.lastTrainedLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Text(statusLabel(stat))
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor(stat).opacity(0.16), in: .capsule)
                .foregroundStyle(statusColor(stat))
        }
    }

    private var quickStatsCard: some View {
        @Bindable var stats = stats
        let current = totals

        return Card(title: "Sur la période", systemImage: "chart.bar.fill") {
            VStack(spacing: 12) {
                RangePicker(range: $stats.range)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    StatTile(
                        title: "Séances",
                        value: current.sessionCount.cleanInt,
                        subtitle: current.currentStreakWeeks > 0
                            ? "\(current.currentStreakWeeks) sem. d'affilée"
                            : nil,
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
                        title: "Fréquence",
                        value: current.sessionsPerWeek.formatted(.number.precision(.fractionLength(1))),
                        unit: "séances/sem.",
                        subtitle: current.averageDuration.map { "≈ \(DurationFormatter.workout($0))" },
                        systemImage: "speedometer",
                        tint: .purple
                    )
                }
            }
        }
    }

    private var balanceCard: some View {
        Card(title: "Volume par groupe musculaire", systemImage: "figure.strengthtraining.traditional") {
            VStack(alignment: .leading, spacing: 14) {
                MuscleShareChart(stats: periodVolumes)
                Divider()
                MuscleRankingList(stats: periodVolumes)
            }
        }
    }

    private var heatmapCard: some View {
        let weeks = stats.heatmap(sessions, weeks: 26)
        let current = totals

        return Card(title: "Assiduité", systemImage: "square.grid.3x3.fill") {
            VStack(alignment: .leading, spacing: 10) {
                AttendanceHeatmap(weeks: weeks)
                HStack(spacing: 14) {
                    Label("\(current.currentStreakDays) j d'affilée", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Label("\(current.currentStreakWeeks) sem. consécutives", systemImage: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var linksCard: some View {
        VStack(spacing: 10) {
            NavigationLink {
                StatsDetailView()
            } label: {
                NavRow(
                    title: "Statistiques détaillées",
                    systemImage: "chart.line.uptrend.xyaxis",
                    subtitle: "Courbes de progression, records, équilibre"
                )
            }

            NavigationLink {
                BodyWeightView()
            } label: {
                NavRow(
                    title: "Poids de corps",
                    systemImage: "figure.stand",
                    tint: .indigo,
                    subtitle: latestBodyWeightLabel
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var latestBodyWeightLabel: String {
        guard let last = bodyWeights.first else { return "Aucune pesée enregistrée" }
        return "Dernière : \(last.kilograms.cleanWeight) kg · \(last.date.shortDayLabel)"
    }

    // MARK: - Actions

    private func startSuggestion(_ current: SessionSuggestion) {
        if let routine = activeRoutine,
           current.routineDayName != nil,
           let day = routine.nextDay {
            sessionVM.startSession(from: routine, day: day, history: completedSessions)
        } else {
            sessionVM.startSession(
                for: current.groups.map(\.group),
                library: exercises,
                history: completedSessions
            )
        }
        selectedTab = .session
    }

    private func statusLabel(_ stat: MuscleRecoveryStat) -> String {
        switch stat.state {
        case .never: "Jamais"
        case .recovering:
            stat.daysSince.map { "Récup · \(Int($0.rounded(.down))) j" } ?? "Récup"
        case .ready:
            stat.wholeDaysSince.map { "Prêt · \($0) j" } ?? "Prêt"
        case .overdue:
            stat.wholeDaysSince.map { "À faire · \($0) j" } ?? "À faire"
        }
    }

    private func statusColor(_ stat: MuscleRecoveryStat) -> Color {
        switch stat.state {
        case .never: .gray
        case .recovering: .orange
        case .ready: .green
        case .overdue: .accentColor
        }
    }
}
