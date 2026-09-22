import SwiftData
import SwiftUI

/// Routines réutilisables (Push/Pull/Legs, Haut/Bas, Full body…).
/// Une seule routine est active : elle pilote la suggestion de séance.
struct RoutinesView: View {

    @Environment(\.modelContext) private var context
    @Environment(ActiveSessionViewModel.self) private var sessionVM

    @Query(sort: [SortDescriptor(\Routine.createdAt)])
    private var routines: [Routine]

    @Query(sort: [SortDescriptor(\WorkoutSession.date, order: .reverse)])
    private var sessions: [WorkoutSession]

    @State private var newRoutine: Routine?

    private var history: [WorkoutSession] { sessions.filter { !$0.isInProgress } }
    private var activeRoutine: Routine? { routines.first { $0.isActive } }

    var body: some View {
        List {
            if let routine = activeRoutine, let day = routine.nextDay {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Prochaine séance", systemImage: "arrow.forward.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(routine.name) — \(day.name)")
                            .font(.headline)
                        Text("\(day.orderedExercises.count) exercices · \(day.muscleGroups.map(\.shortTitle).joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            sessionVM.startSession(from: routine, day: day, history: history)
                        } label: {
                            Label("Démarrer cette séance", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(sessionVM.session != nil)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Routine active").textCase(nil)
                }
            }

            Section {
                if routines.isEmpty {
                    EmptyStateView(
                        title: "Aucune routine",
                        message: "Crée un cycle Push/Pull/Legs ou Haut/Bas pour que l'app te dise quoi faire chaque jour.",
                        systemImage: "list.bullet.rectangle.portrait",
                        action: (title: "Créer une routine", handler: createRoutine)
                    )
                    .listRowBackground(Color.clear)
                }

                ForEach(routines) { routine in
                    NavigationLink {
                        RoutineEditorView(routine: routine)
                    } label: {
                        routineRow(routine)
                    }
                }
                .onDelete(perform: delete)
            } header: {
                Text("Mes routines").textCase(nil)
            } footer: {
                Text("Active une routine pour que MuscuLog suive automatiquement où tu en es dans le cycle.")

            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    createRoutine()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $newRoutine) { routine in
            RoutineEditorView(routine: routine)
        }
    }

    private func routineRow(_ routine: Routine) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(routine.name)
                    .font(.subheadline.weight(.semibold))
                if routine.isActive {
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.18), in: .capsule)
                        .foregroundStyle(.green)
                }
            }
            Text(routine.orderedDays.isEmpty
                 ? "Aucun jour défini"
                 : routine.orderedDays.map(\.name).joined(separator: " → "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if routine.isActive, let next = routine.nextDay {
                Label("Prochain : \(next.name)", systemImage: "arrow.forward")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }

    private func createRoutine() {
        let routine = Routine(name: "Nouvelle routine")
        context.insert(routine)

        let day = RoutineDay(name: "Jour 1", order: 0)
        context.insert(day)
        routine.attach(day)

        try? context.save()
        newRoutine = routine
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(routines[index])
        }
        try? context.save()
        Haptics.warning()
    }
}

/// Édition d'une routine : nom, cycle de jours, exercices cibles.
struct RoutineEditorView: View {

    @Bindable var routine: Routine

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Routine.createdAt)])
    private var allRoutines: [Routine]

    @State private var pickerDay: RoutineDay?
    @State private var newDayName = ""
    @State private var isDeleteAlertPresented = false

    var body: some View {
        List {
            Section("Nom") {
                TextField("Push / Pull / Legs", text: $routine.name)
            }

            Section {
                Toggle(isOn: activationBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Routine active")
                        Text("L'app proposera la séance suivante du cycle.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(routine.orderedDays) { day in
                Section {
                    ForEach(day.orderedExercises) { line in
                        exerciseLine(line)
                    }
                    .onDelete { offsets in
                        deleteExercises(offsets, in: day)
                    }

                    Button {
                        pickerDay = day
                    } label: {
                        Label("Ajouter un exercice", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                } header: {
                    HStack {
                        TextField("Nom du jour", text: dayNameBinding(day))
                            .font(.subheadline.weight(.semibold))
                            .textCase(nil)
                        Spacer()
                        Menu {
                            Button("Monter", systemImage: "arrow.up") { move(day, by: -1) }
                            Button("Descendre", systemImage: "arrow.down") { move(day, by: 1) }
                            Button("Supprimer ce jour", systemImage: "trash", role: .destructive) {
                                delete(day)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.footnote)
                                .textCase(nil)
                        }
                    }
                }
            }

            Section {
                HStack {
                    TextField("Nouveau jour (ex. Push)", text: $newDayName)
                    Button {
                        addDay()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newDayName.trimmed.isEmpty)
                }
            } footer: {
                Text("Un cycle peut contenir autant de jours que tu veux : 3 pour un PPL, 2 pour un Haut/Bas.")
            }

            Section {
                Button("Supprimer la routine", role: .destructive) {
                    isDeleteAlertPresented = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(routine.name.isEmpty ? "Routine" : routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Terminé") {
                    try? context.save()
                    dismiss()
                }
            }
        }
        .sheet(item: $pickerDay) { day in
            ExercisePickerView { exercise in
                addExercise(exercise, to: day)
            }
        }
        .alert("Supprimer cette routine ?", isPresented: $isDeleteAlertPresented) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                context.delete(routine)
                try? context.save()
                dismiss()
            }
        }
    }

    // MARK: - Lignes

    private func exerciseLine(_ line: RoutineDayExercise) -> some View {
        @Bindable var line = line

        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(line.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    ForEach(line.muscleGroups) { group in
                        MuscleTag(group: group)
                    }
                }
            }

            Spacer(minLength: 2)

            // Cible séries × répétitions : un simple menu évite les steppers
            // serrés sur un écran de téléphone.
            Menu {
                Picker("Séries", selection: $line.targetSets) {
                    ForEach(1...12, id: \.self) { value in
                        Text("\(value) séries").tag(value)
                    }
                }
                Picker("Répétitions", selection: $line.targetReps) {
                    ForEach(1...30, id: \.self) { value in
                        Text("\(value) répétitions").tag(value)
                    }
                }
            } label: {
                Text("\(line.targetSets) × \(line.targetReps)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.14), in: .capsule)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Liaisons

    private var activationBinding: Binding<Bool> {
        Binding(
            get: { routine.isActive },
            set: { newValue in
                routine.isActive = newValue
                if newValue {
                    for other in allRoutines where other.id != routine.id {
                        other.isActive = false
                    }
                }
                try? context.save()
                Haptics.success()
            }
        )
    }

    private func dayNameBinding(_ day: RoutineDay) -> Binding<String> {
        Binding(get: { day.name }, set: { day.name = $0 })
    }

    // MARK: - Actions

    private func addDay() {
        let name = newDayName.trimmed
        guard !name.isEmpty else { return }
        let day = RoutineDay(name: name, order: routine.orderedDays.count)
        context.insert(day)
        routine.attach(day)
        newDayName = ""
        try? context.save()
        Haptics.tap()
    }

    private func addExercise(_ exercise: Exercise, to day: RoutineDay) {
        let line = RoutineDayExercise(
            exercise: exercise,
            order: day.orderedExercises.count,
            targetSets: 3,
            targetReps: 10
        )
        context.insert(line)
        day.attach(line)
        try? context.save()
        Haptics.success()
    }

    private func deleteExercises(_ offsets: IndexSet, in day: RoutineDay) {
        let ordered = day.orderedExercises
        for index in offsets where ordered.indices.contains(index) {
            context.delete(ordered[index])
        }
        try? context.save()
    }

    private func delete(_ day: RoutineDay) {
        context.delete(day)
        for (index, remaining) in routine.orderedDays.enumerated() {
            remaining.order = index
        }
        try? context.save()
    }

    private func move(_ day: RoutineDay, by offset: Int) {
        var ordered = routine.orderedDays
        guard let index = ordered.firstIndex(where: { $0.id == day.id }) else { return }
        let target = index + offset
        guard ordered.indices.contains(target) else { return }
        ordered.swapAt(index, target)
        for (position, element) in ordered.enumerated() {
            element.order = position
        }
        try? context.save()
    }
}
