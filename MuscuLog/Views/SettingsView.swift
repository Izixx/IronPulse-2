import SwiftData
import SwiftUI
import UserNotifications

/// Réglages : export des données (crucial en sideload), rappels locaux,
/// minuteur de repos, HealthKit et remise à zéro.
struct SettingsView: View {

    @Environment(\.modelContext) private var context
    @Environment(ActiveSessionViewModel.self) private var sessionVM

    @Query(sort: [SortDescriptor(\WorkoutSession.date, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query(sort: [SortDescriptor(\Exercise.name)])
    private var exercises: [Exercise]

    @Query(sort: [SortDescriptor(\Routine.createdAt)])
    private var routines: [Routine]

    @Query(sort: [SortDescriptor(\BodyWeightEntry.date, order: .reverse)])
    private var bodyWeights: [BodyWeightEntry]

    @AppStorage("musculog.reminderEnabled") private var reminderEnabled = false
    @AppStorage("musculog.reminderHour") private var reminderHour = 18
    @AppStorage("musculog.reminderMinute") private var reminderMinute = 0
    @AppStorage("musculog.haptics") private var hapticsEnabled = true

    @State private var jsonURL: URL?
    @State private var csvURL: URL?
    @State private var exportError: String?
    @State private var isResetAlertPresented = false
    @State private var healthKitEnabled = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private let restOptions: [Double] = [30, 45, 60, 90, 120, 150, 180, 240, 300]

    var body: some View {
        List {
            exportSection
            reminderSection
            restSection
            healthSection
            dangerSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            prepareExports()
            notificationStatus = await NotificationService.authorizationStatus()
            healthKitEnabled = HealthKitService.isEnabled
        }
        .alert("Effacer toutes les données ?", isPresented: $isResetAlertPresented) {
            Button("Annuler", role: .cancel) {}
            Button("Tout effacer", role: .destructive) { resetAllData() }
        } message: {
            Text("Séances, exercices personnalisés, routines et pesées seront supprimés. Pense à exporter avant !")
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        Section {
            if let jsonURL {
                ShareLink(item: jsonURL) {
                    Label("Exporter en JSON", systemImage: "curlybraces")
                }
            }
            if let csvURL {
                ShareLink(item: csvURL) {
                    Label("Exporter en CSV (Excel / Sheets)", systemImage: "tablecells")
                }
            }
            if let exportError {
                Label(exportError, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Text("\(sessions.count) séances · \(exercises.count) exercices · \(bodyWeights.count) pesées")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Sauvegarde")
        } footer: {
            Text("Avec un Apple ID gratuit, la signature Sideloadly expire au bout de 7 jours. Réinstaller l'app peut effacer les données : exporte régulièrement, puis garde le fichier dans Fichiers ou envoie-le-toi par mail.")
        }
    }

    // MARK: - Rappels

    private var reminderSection: some View {
        Section {
            Toggle("Rappel d'entraînement", isOn: $reminderEnabled)
                .onChange(of: reminderEnabled) { _, isOn in
                    Task { await applyReminder(enabled: isOn) }
                }

            if reminderEnabled {
                DatePicker(
                    "Heure",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
            }

            if notificationStatus == .denied {
                Label(
                    "Notifications refusées : active-les dans Réglages iOS → MuscuLog → Notifications.",
                    systemImage: "bell.slash"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
        } header: {
            Text("Rappels")
        } footer: {
            Text("Notifications locales uniquement : rien ne transite par un serveur, et aucune autorisation push n'est nécessaire.")
        }
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = reminderHour
                components.minute = reminderMinute
                return Calendar.current.date(from: components) ?? .now
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = parts.hour ?? 18
                reminderMinute = parts.minute ?? 0
                if reminderEnabled {
                    NotificationService.scheduleWorkoutReminder(
                        hour: reminderHour,
                        minute: reminderMinute
                    )
                }
            }
        )
    }

    private func applyReminder(enabled: Bool) async {
        if enabled {
            let granted = await NotificationService.requestAuthorization()
            notificationStatus = await NotificationService.authorizationStatus()
            guard granted else {
                reminderEnabled = false
                Haptics.warning()
                return
            }
            NotificationService.scheduleWorkoutReminder(hour: reminderHour, minute: reminderMinute)
            Haptics.success()
        } else {
            NotificationService.cancelWorkoutReminders()
            Haptics.tap()
        }
    }

    // MARK: - Minuteur de repos

    private var restSection: some View {
        @Bindable var sessionVM = sessionVM

        return Section {
            Picker("Durée de repos", selection: $sessionVM.restDuration) {
                ForEach(restOptions, id: \.self) { value in
                    Text(restLabel(value)).tag(value)
                }
            }

            Toggle("Notification de fin de repos", isOn: $sessionVM.restNotificationsEnabled)

            Toggle("Retour haptique", isOn: $hapticsEnabled)
        } header: {
            Text("Séance")
        } footer: {
            Text("Le minuteur continue même si tu quittes l'app : la notification arrive à l'heure prévue.")
        }
    }

    private func restLabel(_ value: Double) -> String {
        let seconds = Int(value)
        guard seconds >= 60 else { return "\(seconds) s" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0 ? "\(minutes) min" : "\(minutes) min \(remainder) s"
    }

    // MARK: - Santé

    private var healthSection: some View {
        Section {
            Toggle("Synchroniser avec Santé", isOn: $healthKitEnabled)
                .disabled(!HealthKitService.isAvailable)
                .onChange(of: healthKitEnabled) { _, isOn in
                    Task { await applyHealthKit(enabled: isOn) }
                }

            NavigationLink {
                BodyWeightView()
            } label: {
                Label("Suivi du poids de corps", systemImage: "figure.stand")
            }
        } header: {
            Text("Santé")
        } footer: {
            if HealthKitService.isAvailable {
                Text("Écrit les séances dans Santé et lit ton poids pour le suivi.")
            } else {
                Text("Version compilée sans HealthKit : l'entitlement santé n'est pas disponible avec un Apple ID gratuit. Voir le README pour l'activer avec un compte développeur payant.")
            }
        }
    }

    private func applyHealthKit(enabled: Bool) async {
        guard enabled else {
            HealthKitService.isEnabled = false
            return
        }
        let granted = await HealthKitService.requestAuthorization()
        HealthKitService.isEnabled = granted
        healthKitEnabled = granted
        if granted { Haptics.success() } else { Haptics.warning() }
    }

    // MARK: - Zone de danger

    private var dangerSection: some View {
        Section {
            Button("Effacer toutes les données", role: .destructive) {
                isResetAlertPresented = true
            }
        } header: {
            Text("Données")
        } footer: {
            Text("Toutes les données restent sur cet iPhone (SwiftData). Rien n'est envoyé à un serveur, il n'y a ni compte ni synchronisation cloud.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Séances", value: "\(sessions.count)")
            LabeledContent("Exercices", value: "\(exercises.count)")
            LabeledContent("Routines", value: "\(routines.count)")
        } header: {
            Text("À propos")
        } footer: {
            Text("MuscuLog · app SwiftUI + SwiftData, installée par sideload, aucune connexion réseau requise.")
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Actions

    private func prepareExports() {
        let payload = ExportService.makePayload(
            sessions: sessions,
            exercises: exercises,
            routines: routines,
            bodyWeights: bodyWeights
        )

        do {
            let json = try ExportService.jsonData(for: payload)
            jsonURL = try ExportService.write(json, fileExtension: "json")
        } catch {
            exportError = "Export JSON impossible : \(error.localizedDescription)"
        }

        let csv = ExportService.csv(for: sessions)
        csvURL = try? ExportService.write(Data(csv.utf8), fileExtension: "csv")
    }

    private func resetAllData() {
        try? context.delete(model: WorkoutSession.self)
        try? context.delete(model: Exercise.self)
        try? context.delete(model: Routine.self)
        try? context.delete(model: BodyWeightEntry.self)
        try? context.save()

        // On remet la bibliothèque de départ, comme au premier lancement.
        SeedData.seedIfNeeded(context: context)
        sessionVM.discard(reason: "Données effacées")
        Haptics.warning()
    }
}
