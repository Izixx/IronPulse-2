import SwiftData
import SwiftUI

/// Sélecteur d'exercice pour la séance en cours : recherche instantanée,
/// filtres par groupe musculaire, et création rapide d'un exercice perso.
struct ExercisePickerView: View {

    let onPick: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<Exercise> { $0.isArchived == false },
        sort: [SortDescriptor(\Exercise.name)]
    )
    private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var selectedGroup: MuscleGroup?
    @State private var isCreating = false

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            if let selectedGroup, !exercise.muscleGroups.contains(selectedGroup) { return false }
            return exercise.matches(searchText: searchText)
        }
    }

    /// Regroupement par muscle principal : on retrouve un exercice en le
    /// cherchant là où on l'attend.
    private var grouped: [MuscleExerciseGroup] {
        MuscleGroup.allCases.compactMap { group in
            let items = filtered.filter { $0.primaryMuscleGroup == group }
            return items.isEmpty ? nil : MuscleExerciseGroup(group: group, items: items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    EmptyStateView(
                        title: "Aucun exercice trouvé",
                        message: "Essaie un autre mot, ou crée ton propre exercice.",
                        systemImage: "magnifyingglass",
                        action: (title: "Créer un exercice", handler: { isCreating = true })
                    )
                    .listRowBackground(Color.clear)
                }

                ForEach(grouped) { section in
                    Section {
                        ForEach(section.items) { exercise in
                            Button {
                                onPick(exercise)
                                Haptics.success()
                                dismiss()
                            } label: {
                                row(for: exercise)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Label(section.group.title, systemImage: section.group.symbolName)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Rechercher un exercice")
            .navigationTitle("Ajouter un exercice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreating = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                groupFilterBar
            }
            .sheet(isPresented: $isCreating) {
                ExerciseEditView(exercise: nil)
            }
        }
    }

    private var groupFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "Tous", tint: .accentColor, isSelected: selectedGroup == nil) {
                    selectedGroup = nil
                }
                ForEach(MuscleGroup.allCases) { group in
                    filterChip(
                        title: group.shortTitle,
                        tint: group.tint,
                        isSelected: selectedGroup == group
                    ) {
                        selectedGroup = (selectedGroup == group) ? nil : group
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func filterChip(
        title: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.snappy) { action() }
            Haptics.tap()
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isSelected ? tint.opacity(0.9) : tint.opacity(0.12),
                    in: .capsule
                )
                .foregroundStyle(isSelected ? Color.white : tint)
        }
        .buttonStyle(.plain)
    }

    private func row(for exercise: Exercise) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    ForEach(exercise.muscleGroups) { group in
                        MuscleTag(group: group)
                    }
                    if let equipment = exercise.equipment {
                        Text(equipment)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.accentColor)
        }
        .contentShape(.rect)
    }
}
