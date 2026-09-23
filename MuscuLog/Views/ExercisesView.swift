import SwiftData
import SwiftUI
import UIKit

/// Bibliothèque d'exercices : recherche, filtres par groupe musculaire,
/// création et accès au détail (records + courbes).
struct ExercisesView: View {

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

    private var grouped: [MuscleExerciseGroup] {
        MuscleGroup.allCases.compactMap { group in
            let items = filtered.filter { $0.muscleGroups.contains(group) }
            return items.isEmpty ? nil : MuscleExerciseGroup(group: group, items: items)
        }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                EmptyStateView(
                    title: "Aucun exercice",
                    message: searchText.isEmpty
                        ? "Ajoute un mouvement pour commencer."
                        : "Rien ne correspond à « \(searchText) ».",
                    systemImage: "dumbbell",
                    action: (title: "Nouvel exercice", handler: { isCreating = true })
                )
                .listRowBackground(Color.clear)
            }

            ForEach(grouped) { section in
                Section {
                    ForEach(section.items) { exercise in
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise)
                        } label: {
                            row(for: exercise)
                        }
                    }
                } header: {
                    Label(section.group.title, systemImage: section.group.symbolName)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Rechercher")
        .safeAreaInset(edge: .top) { groupFilterBar }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreating = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            ExerciseEditView(exercise: nil)
        }
    }

    private var groupFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Tous", tint: .accentColor, isSelected: selectedGroup == nil) {
                    selectedGroup = nil
                }
                ForEach(MuscleGroup.allCases) { group in
                    chip(title: group.shortTitle, tint: group.tint, isSelected: selectedGroup == group) {
                        selectedGroup = (selectedGroup == group) ? nil : group
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func chip(
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
                .background(isSelected ? tint.opacity(0.9) : tint.opacity(0.12), in: .capsule)
                .foregroundStyle(isSelected ? Color.white : tint)
        }
        .buttonStyle(.plain)
    }

    private func row(for exercise: Exercise) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ExerciseThumbView(exercise: exercise, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline.weight(.medium))
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
        }
        .padding(.vertical, 2)
    }
}
