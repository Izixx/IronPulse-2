import SwiftData
import SwiftUI

/// Création / édition d'un exercice : nom, groupes musculaires, équipement,
/// photo de la machine (ex. Technogym du club) et URL d'image de référence.
struct ExerciseEditView: View {

    /// `nil` pour une création.
    let exercise: Exercise?
    /// Photo prise en amont (ex. « Photographier une machine » du picker).
    var initialImage: UIImage? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String = ""
    @State private var muscleGroups: Set<MuscleGroup> = []
    @State private var equipment: String = ""
    @State private var remoteURL: String = ""
    @State private var pendingImage: UIImage?
    @State private var removedPhoto = false
    @State private var activePhotoSource: ExercisePhotoPicker.Source?
    @State private var cameraUnavailableAlert = false
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

                photoSection
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
            .sheet(item: $activePhotoSource) { source in
                ExercisePhotoPicker(source: source) { image in
                    pendingImage = image
                    removedPhoto = false
                    Haptics.success()
                }
                .ignoresSafeArea()
            }
            .alert("Appareil photo indisponible", isPresented: $cameraUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("La photothèque reste disponible pour associer une image à cet exercice.")
            }
        }
    }

    // MARK: - Section photo

    private var photoSection: some View {
        Section {
            if let preview {
                VStack(spacing: 10) {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipShape(.rect(cornerRadius: 12))
                        .accessibilityLabel("Photo de l'exercice")
                    HStack(spacing: 10) {
                        photoButton("Reprendre", "camera.fill", .camera)
                        photoButton("Photothèque", "photo.on.rectangle", .library)
                        Button(role: .destructive) {
                            pendingImage = nil
                            removedPhoto = true
                            remoteURL = ""
                            Haptics.tap()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("Photographie ta machine pour la reconnaître d'un coup d'œil")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 10) {
                        photoButton("Caméra", "camera.fill", .camera)
                        photoButton("Photothèque", "photo.on.rectangle", .library)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        } header: {
            Text("Photo de l'appareil")
        } footer: {
            Text("La photo est compressée et reste sur ton téléphone. Une URL d'image (site du constructeur, réservoir…) peut servir de référence en complément.")
        }
    }

    /// Aperçu : nouvelle photo pending, sinon photo existante (sauf si supprimée).
    private var preview: UIImage? {
        if let pendingImage { return pendingImage }
        if removedPhoto { return nil }
        return exercise?.photo
    }

    private func photoButton(
        _ title: String,
        _ systemImage: String,
        _ source: ExercisePhotoPicker.Source
    ) -> some View {
        Button {
            if source == .camera, !UIImagePickerController.isSourceTypeAvailable(.camera) {
                cameraUnavailableAlert = true
                return
            }
            activePhotoSource = source
        } label: {
            Label(title, systemImage: systemImage)
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
        if let exercise {
            name = exercise.name
            muscleGroups = Set(exercise.muscleGroups)
            equipment = exercise.equipment ?? ""
            remoteURL = exercise.remoteImageURL ?? ""
        } else if let initialImage {
            pendingImage = initialImage
        }
    }

    private func save() {
        let groups = MuscleGroup.allCases.filter { muscleGroups.contains($0) }
        let trimmedEquipment = equipment.trimmed
        let target = exercise ?? Exercise(
            name: name.trimmed,
            muscleGroups: groups,
            equipment: trimmedEquipment.isEmpty ? nil : trimmedEquipment,
            isCustom: true
        )

        target.name = name.trimmed
        target.setMuscleGroups(groups)
        target.equipment = trimmedEquipment.isEmpty ? nil : trimmedEquipment
        target.setRemoteImageURL(remoteURL)

        if removedPhoto {
            target.setPhoto(nil)
        } else if let pendingImage {
            target.setPhoto(pendingImage)
        }

        if exercise == nil {
            context.insert(target)
        }

        try? context.save()
        Haptics.success()
        dismiss()
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
