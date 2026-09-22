import SwiftData
import SwiftUI

/// Suivi du poids de corps : courbe dédiée, saisie rapide, tendance.
struct BodyWeightView: View {

    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\BodyWeightEntry.date, order: .reverse)])
    private var entries: [BodyWeightEntry]

    @State private var inputWeight: Double = 0
    @State private var inputDate: Date = .now
    @State private var isImporting = false

    private var sortedEntries: [BodyWeightEntry] {
        entries.sorted { $0.date < $1.date }
    }

    private var latest: BodyWeightEntry? {
        sortedEntries.last
    }

    /// Variation par rapport à la pesée la plus proche d'il y a 30 jours.
    private var monthlyDelta: Double? {
        guard let latest else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let reference = sortedEntries.last { $0.date <= cutoff } ?? sortedEntries.first
        guard let reference, reference.id != latest.id else { return nil }
        return latest.kilograms - reference.kilograms
    }

    var body: some View {
        List {
            Section {
                if sortedEntries.count >= 2 {
                    BodyWeightChart(entries: entries)
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 16))
                } else {
                    EmptyStateView(
                        title: "Pas encore de courbe",
                        message: "Ajoute au moins deux pesées pour voir une tendance.",
                        systemImage: "figure.stand"
                    )
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("Évolution").textCase(nil)
            }

            Section {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    StatTile(
                        title: "Poids actuel",
                        value: latest?.kilograms.cleanWeight ?? "—",
                        unit: "kg",
                        subtitle: latest.map { $0.date.shortDayLabel },
                        systemImage: "figure.stand",
                        tint: .indigo
                    )
                    StatTile(
                        title: "Variation 30 j",
                        value: monthlyDelta.map { ($0 >= 0 ? "+" : "") + $0.cleanWeight } ?? "—",
                        unit: "kg",
                        subtitle: "vs il y a un mois",
                        systemImage: "arrow.up.arrow.down",
                        tint: (monthlyDelta ?? 0) >= 0 ? .orange : .green
                    )
                    StatTile(
                        title: "Minimum",
                        value: sortedEntries.map(\.kilograms).min()?.cleanWeight ?? "—",
                        unit: "kg",
                        systemImage: "arrow.down",
                        tint: .green
                    )
                    StatTile(
                        title: "Maximum",
                        value: sortedEntries.map(\.kilograms).max()?.cleanWeight ?? "—",
                        unit: "kg",
                        systemImage: "arrow.up",
                        tint: .red
                    )
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            }

            Section {
                HStack(spacing: 12) {
                    NumberField(
                        title: "kg",
                        value: $inputWeight,
                        step: 0.5,
                        unit: "kg",
                        fieldWidth: 50
                    )
                    DatePicker("Date", selection: $inputDate, displayedComponents: .date)
                        .labelsHidden()
                    Spacer(minLength: 0)
                }

                Button {
                    addEntry()
                } label: {
                    Label("Enregistrer la pesée", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .disabled(inputWeight <= 0)

                if HealthKitService.isAvailable {
                    Button {
                        Task { await importFromHealth() }
                    } label: {
                        if isImporting {
                            HStack { ProgressView(); Text("Lecture de Santé…") }
                        } else {
                            Label("Importer depuis Santé", systemImage: "heart.fill")
                        }
                    }
                    .disabled(isImporting)
                }
            } header: {
                Text("Ajouter").textCase(nil)
            } footer: {
                Text("Pèse-toi toujours dans les mêmes conditions (matin à jeun) pour que la tendance soit exploitable.")
            }

            if !entries.isEmpty {
                Section {
                    ForEach(entries) { entry in
                        HStack {
                            Text(entry.date.dayLabel)
                                .font(.subheadline)
                            Spacer()
                            Text("\(entry.kilograms.cleanWeight) kg")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            if entry.importedFromHealth {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.pink)
                            }
                        }
                    }
                    .onDelete { offsets in
                        delete(offsets)
                    }
                } header: {
                    Text("Historique").textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Poids de corps")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if inputWeight == 0, let last = latest {
                inputWeight = last.kilograms
            }
        }
    }

    // MARK: - Actions

    private func addEntry() {
        guard inputWeight > 0 else { return }
        let entry = BodyWeightEntry(date: inputDate, kilograms: inputWeight)
        context.insert(entry)
        try? context.save()
        Haptics.success()
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets where entries.indices.contains(index) {
            context.delete(entries[index])
        }
        try? context.save()
        Haptics.warning()
    }

    private func importFromHealth() async {
        isImporting = true
        defer { isImporting = false }

        guard let sample = await HealthKitService.latestBodyMass() else { return }

        // Un seul enregistrement par jour : on remplace si la date existe déjà.
        if let existing = entries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: sample.date) }) {
            existing.kilograms = sample.kilograms
            existing.importedFromHealth = true
        } else {
            let entry = BodyWeightEntry(
                date: sample.date,
                kilograms: sample.kilograms,
                note: nil,
                importedFromHealth: true
            )
            context.insert(entry)
        }
        try? context.save()
        Haptics.success()
    }
}
