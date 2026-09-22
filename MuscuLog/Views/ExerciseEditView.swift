import SwiftData
import SwiftUI

/// Création / édition d'un exercice (nom, groupes musculaires, équipement).
struct ExerciseEditView: View {

    /// `nil` pour une création.
    let exercise: Exercise?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String = ""
    @State private var muscleGroups: Set<MuscleGroup> = []
    @State private var equipment: String = ""
    @State private var didLoad = false

    private var isEditing: Bool { exercise != nil }
    private var canSave: Bool { !name.trimmed.isEmpty && !muscleGroups.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom") {
                    TextField("Développé couché", text: $name)
                        .autocorrectionDisabled()
                }

                Section {
                    ForEach(MuscleGroup.allCases) { group in
                        Button {
                            toggle(group)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: group.symbolName)
                                    .frame(width: 22)
                                    .foregroundStyle(group.tint)
                                Text(group.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if muscleGroups.contains(group) {
                                    Image(systemName: "checkmark")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Groupes musculaires")
                } footer: {
                    Text("Choisis-en plusieurs pour un mouvement polyarticulaire (ex. développé couché : pectoraux, triceps, épaules). Le volume sera réparti entre eux.")
                }

                Section("Équipement (optionnel)") {
                    TextField("Barre, haltères, machine, poulie…", text: $equipment)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(isEditing ? "Modifier l'exercice" : "Nouvel exercice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func toggle(_ group: MuscleGroup) {
        if muscleGroups.contains(group) {
            muscleGroups.remove(group)
        } else {
            muscleGroups.insert(group)
        }
        Haptics.tap()
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let exercise else { return }
        name = exercise.name
        muscleGroups = Set(exercise.muscleGroups)
        equipment = exercise.equipment ?? ""
    }

    private func save() {
        let groups = MuscleGroup.allCases.filter { muscleGroups.contains($0) }
        let trimmedEquipment = equipment.trimmed

        if let exercise {
            exercise.name = name.trimmed
            exercise.setMuscleGroups(groups)
            exercise.equipment = trimmedEquipment.isEmpty ? nil : trimmedEquipment
        } else {
            let created = Exercise(
                name: name.trimmed,
                muscleGroups: groups,
                equipment: trimmedEquipment.isEmpty ? nil : trimmedEquipment,
                isCustom: true
            )
            context.insert(created)
        }

        try? context.save()
        Haptics.success()
        dismiss()
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
