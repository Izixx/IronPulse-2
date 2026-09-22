import SwiftData
import SwiftUI

/// Onglet Séance. Deux états exclusifs :
/// - aucune séance en cours → écran de démarrage (libre, dernière séance, routine) ;
/// - séance en cours → saisie des séries, minuteur de repos, clôture.
struct ActiveSessionView: View {

    @Binding var selectedTab: AppTab

    @Environment(ActiveSessionViewModel.self) private var sessionVM

    @Query(sort: [SortDescriptor(\WorkoutSession.date, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query(sort: [SortDescriptor(\Routine.createdAt)])
    private var routines: [Routine]

    @State private var isPickerPresented = false
    @State private var isDiscardAlertPresented = false
    @State private var finishedSession: WorkoutSession?

    private var history: [WorkoutSession] {
        sessions.filter { !$0.isInProgress }
    }

    private var activeRoutine: Routine? {
        routines.first { $0.isActive }
    }

    var body: some View {
        Group {
            if let session = sessionVM.session {
                sessionList(session)
            } else {
                startScreen
            }
        }
        .navigationTitle(sessionVM.session == nil ? "Séance" : "Séance en cours")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPickerPresented) {
            ExercisePickerView { exercise in
                guard let session = sessionVM.session else { return }
                sessionVM.addExercise(exercise, to: session, history: history)
            }
        }
        .sheet(item: $finishedSession) { session in
            SessionSummaryView(session: session, history: history)
        }
        .alert("Annuler la séance ?", isPresented: $isDiscardAlertPresented) {
            Button("Continuer", role: .cancel) {}
            Button("Tout supprimer", role: .destructive) {
                sessionVM.discard(reason: "Séance annulée")
            }
        } message: {
            Text("Les séries saisies seront perdues.")
        }
    }

    // MARK: - Écran de démarrage

    private var startScreen: some View {
        ScrollView {
            VStack(spacing: 12) {
                Button {
                    sessionVM.startSession()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                        Text("Démarrer une séance")
                            .font(.title3.weight(.bold))
                        Text("Aujourd'hui · \(Date.now.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .background(Color.accentColor.opacity(0.16), in: .rect(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.accentColor.opacity(0.4), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)

                if let last = history.first {
                    startOption(
                        title: "Refaire la dernière séance",
                        subtitle: "\(last.title) · \(last.date.shortDayLabel) · \(last.totalSets) séries",
                        systemImage: "arrow.counterclockwise",
                        tint: .indigo
                    ) {
                        sessionVM.duplicateLastSession(from: history)
                    }
                }

                if let routine = activeRoutine, let day = routine.nextDay {
                    startOption(
                        title: "\(routine.name) — \(day.name)",
                        subtitle: "Prochaine séance du cycle · \(day.orderedExercises.count) exercices",
                        systemImage: "list.bullet.rectangle.portrait",
                        tint: .blue
                    ) {
                        sessionVM.startSession(from: routine, day: day, history: history)
                    }
                } else if !routines.isEmpty {
                    Card(title: "Aucune routine active", systemImage: "info.circle") {
                        Text("Va dans l'onglet Exercices → Routines pour activer un cycle (Push/Pull/Legs, Haut/Bas…). L'app te proposera alors automatiquement la séance du jour.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func startOption(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        BigActionButton(
            title: title,
            systemImage: systemImage,
            tint: tint,
            subtitle: subtitle,
            action: action
        )
    }

    // MARK: - Séance en cours

    private func sessionList(_ session: WorkoutSession) -> some View {
        List {
            Section {
                sessionHeader(session)
            }

            if sessionVM.isResting, let end = sessionVM.restEndsAt {
                Section {
                    RestTimerBar(
                        endDate: end,
                        total: sessionVM.restDuration,
                        exerciseName: lastRestExerciseName(session),
                        onStop: { sessionVM.stopRest() },
                        onExtend: { sessionVM.extendRest(by: $0) }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowBackground(Color.clear)
                }
            }

            ForEach(session.orderedExercises) { item in
                Section {
                    setRows(item)
                } header: {
                    exerciseHeader(item, in: session)
                }
            }

            Section {
                Button {
                    isPickerPresented = true
                } label: {
                    Label("Ajouter un exercice", systemImage: "plus.circle.fill")
                        .font(.headline)
                }

                Button {
                    finishSession()
                } label: {
                    Label("Terminer la séance", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .disabled(session.exercises.isEmpty)

                Button("Annuler la séance", role: .destructive) {
                    isDiscardAlertPresented = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isPickerPresented = true
                    } label: {
                        Label("Ajouter un exercice", systemImage: "plus")
                    }
                    Button {
                        sessionVM.startRest(exerciseName: nil)
                    } label: {
                        Label("Démarrer un repos", systemImage: "hourglass")
                    }
                    Divider()
                    Button("Terminer la séance", systemImage: "checkmark") {
                        finishSession()
                    }
                    Button("Annuler la séance", systemImage: "trash", role: .destructive) {
                        isDiscardAlertPresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func sessionHeader(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(session.title, systemImage: "figure.strengthtraining.traditional")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(DurationFormatter.workout(context.date.timeIntervalSince(session.startedAt)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Label("\(session.totalSets) séries", systemImage: "square.stack.3d.up")
                Label("\(session.totalVolume.volumeInTonnes) t", systemImage: "scalemass")
                Label("\(session.exercises.count) ex.", systemImage: "list.bullet")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            TextField("Note de ressenti (optionnel)", text: noteBinding(session), axis: .vertical)
                .lineLimit(1...3)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }

    private func exerciseHeader(_ item: WorkoutExercise, in session: WorkoutSession) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.displayName)
                    .font(.headline)
                    .textCase(nil)
                HStack(spacing: 5) {
                    ForEach(item.muscleGroups) { group in
                        MuscleTag(group: group)
                    }
                    Text("\(item.workingSetCount) séries · \(item.volume.cleanVolume) kg")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }

            Spacer(minLength: 4)

            Menu {
                Button {
                    sessionVM.copyLastPerformance(into: item, history: history)
                } label: {
                    Label("Recopier la dernière fois", systemImage: "arrow.counterclockwise")
                }
                Button {
                    sessionVM.addSet(to: item)
                } label: {
                    Label("Ajouter une série", systemImage: "plus")
                }
                Divider()
                Button {
                    sessionVM.move(item, by: -1, in: session)
                } label: {
                    Label("Monter", systemImage: "arrow.up")
                }
                Button {
                    sessionVM.move(item, by: 1, in: session)
                } label: {
                    Label("Descendre", systemImage: "arrow.down")
                }
                Divider()
                Button("Retirer l'exercice", systemImage: "trash", role: .destructive) {
                    sessionVM.removeExercise(item)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
            }
            .textCase(nil)
        }
    }

    @ViewBuilder
    private func setRows(_ item: WorkoutExercise) -> some View {
        ForEach(item.orderedSets) { set in
            setRow(set, number: set.order + 1, item: item)
        }

        Button {
            sessionVM.addSet(to: item)
        } label: {
            Label("Ajouter une série", systemImage: "plus")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func setRow(_ set: SetEntry, number: Int, item: WorkoutExercise) -> some View {
        @Bindable var set = set

        return HStack(spacing: 6) {
            VStack(spacing: 1) {
                Text("\(number)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(set.isWarmup ? .orange : .secondary)
                if set.isWarmup {
                    Text("éch.")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
            .frame(width: 22)

            NumberField(
                title: "reps",
                value: repsBinding(set),
                step: 1,
                unit: "reps",
                fieldWidth: 34
            )

            NumberField(
                title: "kg",
                value: $set.weight,
                step: 2.5,
                unit: "kg",
                fieldWidth: 34
            )

            RPEPicker(rpe: $set.rpe, compact: true)

            Spacer(minLength: 0)

            Menu {
                Button {
                    sessionVM.toggleWarmup(set)
                } label: {
                    Label(
                        set.isWarmup ? "Série de travail" : "Marquer comme échauffement",
                        systemImage: "flame"
                    )
                }
                Button {
                    sessionVM.markSetCompleted(set, exerciseName: item.displayName)
                } label: {
                    Label("Série faite · lancer le repos", systemImage: "hourglass")
                }
                Button {
                    sessionVM.addSet(to: item)
                } label: {
                    Label("Dupliquer la série", systemImage: "plus.square.on.square")
                }
                Divider()
                Button("Supprimer la série", systemImage: "trash", role: .destructive) {
                    sessionVM.removeSet(set)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption.weight(.bold))
                    .frame(width: 22, height: 30)
                    .contentShape(.rect)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Liaisons

    private func repsBinding(_ set: SetEntry) -> Binding<Double> {
        Binding(
            get: { Double(set.reps) },
            set: { set.reps = max(0, Int($0.rounded())) }
        )
    }

    private func noteBinding(_ session: WorkoutSession) -> Binding<String> {
        Binding(
            get: { session.note ?? "" },
            set: { session.note = $0.isEmpty ? nil : $0 }
        )
    }

    private func lastRestExerciseName(_ session: WorkoutSession) -> String? {
        session.orderedExercises.last?.displayName
    }

    // MARK: - Clôture

    private func finishSession() {
        let routine = activeRoutine
        sessionVM.finish(activeRoutine: routine) { finished in
            HealthKitService.saveWorkout(finished)
            WidgetSnapshot.refresh(sessions: sessions, routines: routines)
            WidgetBridge.reload()
            finishedSession = finished
        }
        selectedTab = .home
    }
}

// MARK: - Résumé de fin de séance

/// Récapitule la séance qui vient d'être terminée et met en avant les records
/// battus : c'est la récompense qui donne envie de revenir.
struct SessionSummaryView: View {

    let session: WorkoutSession
    let history: [WorkoutSession]

    @Environment(\.dismiss) private var dismiss
    @Environment(StatsViewModel.self) private var stats

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(.green)
                        Text("Séance enregistrée")
                            .font(.title3.weight(.bold))
                        Text(session.date.formatted(date: .complete, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                        spacing: 10
                    ) {
                        StatTile(
                            title: "Durée",
                            value: session.duration.map { DurationFormatter.workout($0) } ?? "—",
                            systemImage: "clock",
                            tint: .blue
                        )
                        StatTile(
                            title: "Volume",
                            value: session.totalVolume.volumeInTonnes,
                            unit: "t",
                            systemImage: "scalemass.fill",
                            tint: .teal
                        )
                        StatTile(
                            title: "Séries",
                            value: session.totalSets.cleanInt,
                            systemImage: "square.stack.3d.up.fill",
                            tint: .orange
                        )
                        StatTile(
                            title: "Exercices",
                            value: session.exercises.count.cleanInt,
                            systemImage: "list.bullet",
                            tint: .purple
                        )
                    }

                    if !newRecords.isEmpty {
                        Card(title: "Nouveaux records 🎉", systemImage: "trophy.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(newRecords, id: \.self) { line in
                                    Label(line, systemImage: "star.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }

                    Card(title: "Détail", systemImage: "list.bullet.rectangle") {
                        VStack(spacing: 8) {
                            ForEach(session.orderedExercises) { item in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.displayName)
                                            .font(.subheadline.weight(.medium))
                                        Text(item.orderedSets.map(\.summary).joined(separator: "  ·  "))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 4)
                                    Text("\(item.volume.cleanVolume) kg")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                if item.id != session.orderedExercises.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Résumé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    /// Records battus pendant cette séance, comparés à l'historique antérieur.
    private var newRecords: [String] {
        let previous = history.filter { $0.id != session.id }
        var lines: [String] = []

        for item in session.orderedExercises {
            guard let exercise = item.exercise else { continue }
            let before = stats.records(for: exercise, in: previous)
            for set in item.workingSets {
                if set.weight > before.bestWeight, set.weight > 0 {
                    lines.append("\(exercise.name) : \(set.weight.cleanWeight) kg × \(set.reps)")
                } else if set.estimated1RM > before.bestEstimated1RM, before.bestEstimated1RM > 0 {
                    lines.append("\(exercise.name) : 1RM estimé \(set.estimated1RM.cleanWeight) kg")
                }
            }
        }
        return Array(Set(lines)).sorted()
    }
}
