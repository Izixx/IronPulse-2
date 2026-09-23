import SwiftData
import SwiftUI
import UIKit

/// Photo en attente d'affectation (wrapper `Identifiable` pour `sheet(item:)`).
struct PendingExercisePhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Source de photo en attente d'ouverture (idem, pour le `sheet(item:)`).
struct PendingPhotoSource: Identifiable {
    let id = UUID()
    let source: ExercisePhotoPicker.Source
}

/// Sélecteur d'exercice pour la séance en cours : recherche instantanée,
/// filtres par groupe musculaire, onglet « Photos » (tes machines), et
/// création rapide — y compris en photographiant la machine utilisée.
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
    @State private var showingPhotos = false
    @State private var showingSourceDialog = false
    @State private var cameraUnavailable = false
    @State private var pendingCreationPhoto: PendingExercisePhoto?
    @State private var activeCreationSource: PendingPhotoSource?

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

    private var withPhotos: [Exercise] {
        filtered.filter { $0.thumbnail != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                if showingPhotos {
                    photosContent
                } else {
                    listContent
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
                VStack(spacing: 0) {
                    Picker("Mode", selection: $showingPhotos) {
                        Text("Liste").tag(false)
                        Text("Photos").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    groupFilterBar
                }
                .background(.bar)
            }
            .safeAreaInset(edge: .bottom) {
                photoCreationBar
            }
            .sheet(isPresented: $isCreating) {
                ExerciseEditView(exercise: nil)
            }
            .sheet(item: $pendingCreationPhoto) { photo in
                ExerciseEditView(exercise: nil, initialImage: photo.image)
            }
            .sheet(item: $activeCreationSource) { pending in
                ExercisePhotoPicker(source: pending.source) { image in
                    pendingCreationPhoto = PendingExercisePhoto(image: image)
                }
                .ignoresSafeArea()
            }
            .confirmationDialog(
                "Photographier ta machine",
                isPresented: $showingSourceDialog,
                titleVisibility: .visible
            ) {
                Button("Prendre une photo", systemImage: "camera.fill") {
                    openPhotoSource(.camera)
                }
                Button("Choisir dans la photothèque", systemImage: "photo.on.rectangle") {
                    openPhotoSource(.library)
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("La photo est associée à l'exercice : tu retrouveras la machine d'un coup d'œil.")
            }
            .alert("Appareil photo indisponible", isPresented: $cameraUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Utilise la photothèque pour associer une image.")
            }
        }
    }

    // MARK: - Contenus

    @ViewBuilder
    private var listContent: some View {
        if filtered.isEmpty {
            EmptyStateView(
                title: "Aucun exercice trouvé",
                message: "Essaie un autre mot, photographie ta machine, ou crée ton propre exercice.",
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

    @ViewBuilder
    private var photosContent: some View {
        if withPhotos.isEmpty {
            EmptyStateView(
                title: "Aucune photo pour l'instant",
                message: "Photographie tes machines Fitness Park : elles apparaîtront ici et tu les sélectionneras d'un tap.",
                systemImage: "camera.viewfinder",
                action: (title: "Photographier une machine", handler: { showingSourceDialog = true })
            )
            .listRowBackground(Color.clear)
        } else {
            Section {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 104), spacing: 12)],
                    spacing: 14
                ) {
                    ForEach(withPhotos) { exercise in
                        photoCell(exercise)
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Text("\(withPhotos.count) machine(s) photographiée(s)")
                    .textCase(nil)
            } footer: {
                Text("La recherche et les filtres s'appliquent aussi ici.")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        }
    }

    private var photoCreationBar: some View {
        HStack(spacing: 10) {
            Button {
                showingSourceDialog = true
            } label: {
                Label("Photographier une machine", systemImage: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Composants

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
            ExerciseThumbView(exercise: exercise, size: 44)
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

    private func photoCell(_ exercise: Exercise) -> some View {
        Button {
            onPick(exercise)
            Haptics.success()
            dismiss()
        } label: {
            VStack(spacing: 6) {
                ExerciseThumbView(exercise: exercise, size: 104, cornerRadius: 10)
                Text(exercise.name)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    private func openPhotoSource(_ source: ExercisePhotoPicker.Source) {
        if source == .camera, !UIImagePickerController.isSourceTypeAvailable(.camera) {
            cameraUnavailable = true
            return
        }
        activeCreationSource = PendingPhotoSource(source: source)
    }
}
