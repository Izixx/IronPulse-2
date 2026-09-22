import SwiftData
import SwiftUI

/// Détail d'une séance passée, entièrement modifiable : date, ressenti,
/// exercices et séries. Utile quand on a oublié de noter une série en salle.
struct SessionDetailView: View {

    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(StatsViewModel.self) private var stats
    @Environment(ActiveSessionViewModel.self) private var sessionVM

    @Query(sort: [SortDescriptor(\WorkoutSession.date, order: .reverse)])
    private var allSessions: [WorkoutSession]

    @Query(
        filter: #Predicate<Exercise> { $0.isArchived == false },
        sort: [SortDescriptor(\Exercise.name)]
    )
    private var library: [Exercise]

    @State private var isPickerPresented = false
    @State private var isDeleteAlertPresented = false

    private var history: [WorkoutSession] {
        allSessions.filter { !$0.isInProgress && $0.id != session.id }
    }

    var body: some View {
        List {
            Section("Séance") {
                DatePicker(
                    "Date",
                    selection: $session.date,
                    displayedComponents: [.date, .hourAndMinute]
                )
                TextField("Note de ressenti", text: noteBinding, axis: .vertical)
                    .lineLimit(1...4)

                HStack(spacing: 14) {
                    Label("\(session.totalSets) séries", systemImage: "square.stack.3d.up")
                    Label("\(session.totalVolume.volumeInTonnes) t", systemImage: "scalemass")
                    if let duration = session.duration {
                        Label(DurationFormatter.workout(duration), systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ForEach(session.orderedExercises) { item in
                Section {
                    ForEach(item.orderedSets) { set in
                        setRow(set, number: set.order + 1, item: item)
                    }

                    Button {
                        addSet(to: item)
                    } label: {
                        Label("Ajouter une série", systemImage: "plus")
                            .font(.subheadline)
                    }
                } header: {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayName)
                                .font(.headline)
                                .textCase(nil)
                            HStack(spacing: 5) {
                                ForEach(item.muscleGroups) { group in
                                    MuscleTag(group: group)
                                }
                                Text("\(item.volume.cleanVolume) kg")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .textCase(nil)
                            }
                        }
                        Spacer(minLength: 4)
                        Menu {
                            Button {
                                copyLastPerformance(into: item)
                            } label: {
                                Label("Recopier la dernière fois", systemImage: "arrow.counterclockwise")
                            }
                            Button("Retirer l'exercice", systemImage: "trash", role: .destructive) {
                                remove(item)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .textCase(nil)
                        }
                    }
                }
            }

            Section {
                Button {
                    isPickerPresented = true
                } label: {
                    Label("Ajouter un exercice", systemImage: "plus.circle.fill")
                }
            }

            Section {
                Button("Supprimer la séance", role: .destructive) {
                    isDeleteAlertPresented = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(session.date.formatted(.dateTime.day().month(.wide)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") {
                    try? context.save()
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            ExercisePickerView { exercise in
                addExercise(exercise)
            }
        }
        .alert("Supprimer cette séance ?", isPresented: $isDeleteAlertPresented) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                context.delete(session)
                try? context.save()
                dismiss()
            }
        }
    }

    // MARK: - Lignes

    private func setRow(_ set: SetEntry, number: Int, item: WorkoutExercise) -> some View {
        @Bindable var set = set

        return HStack(spacing: 6) {
            Text("\(number)")
                .font(.caption.weight(.bold).monospacedDigit())
                .frame(width: 20)
                .foregroundStyle(set.isWarmup ? .orange : .secondary)

            NumberField(
                title: "reps",
                value: Binding(
                    get: { Double(set.reps) },
                    set: { set.reps = max(0, Int($0.rounded())) }
                ),
                step: 1,
                unit: "reps",
                fieldWidth: 34
            )

            NumberField(title: "kg", value: $set.weight, step: 2.5, unit: "kg", fieldWidth: 34)

            RPEPicker(rpe: $set.rpe, compact: true)

            Spacer(minLength: 0)

            Button {
                sessionVM.toggleWarmup(set)
            } label: {
                Image(systemName: set.isWarmup ? "flame.fill" : "flame")
                    .foregroundStyle(.orange)
                    .frame(width: 26, height: 30)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button {
                removeSet(set, from: item)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(width: 24, height: 30)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Liaisons

    private var noteBinding: Binding<String> {
        Binding(
            get: { session.note ?? "" },
            set: { session.note = $0.isEmpty ? nil : $0 }
        )
    }

    // MARK: - Actions

    private func addSet(to item: WorkoutExercise) {
        let last = item.orderedSets.last
        let entry = SetEntry(
            order: item.nextOrder(),
            reps: last?.reps ?? 10,
            weight: last?.weight ?? 0
        )
        context.insert(entry)
        item.attach(entry)
        try? context.save()
        Haptics.tap()
    }

    private func removeSet(_ set: SetEntry, from item: WorkoutExercise) {
        context.delete(set)
        try? context.save()
        for (index, remaining) in item.orderedSets.enumerated() {
            remaining.order = index
        }
        Haptics.warning()
    }

    private func addExercise(_ exercise: Exercise) {
        let item = WorkoutExercise(exercise: exercise, order: session.nextOrder())
        context.insert(item)
        session.attach(item)

        if let previous = stats.lastPerformedEntry(for: exercise, in: history) {
            for set in previous.workingSets.sorted(by: { $0.order < $1.order }) {
                let copy = SetEntry(order: item.nextOrder(), reps: set.reps, weight: set.weight)
                context.insert(copy)
                item.attach(copy)
            }
        } else {
            for index in 0..<3 {
                let entry = SetEntry(order: index, reps: 10, weight: 0)
                context.insert(entry)
                item.attach(entry)
            }
        }
        try? context.save()
    }

    private func remove(_ item: WorkoutExercise) {
        context.delete(item)
        try? context.save()
        for (index, remaining) in session.orderedExercises.enumerated() {
            remaining.order = index
        }
        Haptics.warning()
    }

    private func copyLastPerformance(into item: WorkoutExercise) {
        guard let exercise = item.exercise else { return }
        guard let previous = stats.lastPerformedEntry(for: exercise, in: history) else { return }

        for set in item.sets {
            context.delete(set)
        }
        for set in previous.workingSets.sorted(by: { $0.order < $1.order }) {
            let copy = SetEntry(order: item.nextOrder(), reps: set.reps, weight: set.weight, rpe: set.rpe)
            context.insert(copy)
            item.attach(copy)
        }
        try? context.save()
        Haptics.success()
    }
}
