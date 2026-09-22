import SwiftData
import SwiftUI

@main
struct MuscuLogApp: App {

    /// Tous les modèles persistés. Ajouter un modèle ici suffit : SwiftData
    /// crée le schéma et gère les migrations légères.
    private static let schema = Schema([
        Exercise.self,
        WorkoutSession.self,
        WorkoutExercise.self,
        SetEntry.self,
        Routine.self,
        RoutineDay.self,
        RoutineDayExercise.self,
        BodyWeightEntry.self
    ])

    private let container: ModelContainer
    @State private var sessionViewModel: ActiveSessionViewModel
    @State private var statsViewModel = StatsViewModel()

    /// Vrai quand SwiftData n'a pas pu ouvrir la base sur le disque et que
    /// l'app tourne sur un stockage volatil : rien n'est alors conservé.
    @State private var storageIsEphemeral = false

    init() {
        let storage = MuscuLogApp.makeContainer()
        self.container = storage.container
        _storageIsEphemeral = State(initialValue: storage.isEphemeral)

        let context = storage.container.mainContext
        _sessionViewModel = State(initialValue: ActiveSessionViewModel(context: context))

        // Bibliothèque d'exercices + routines types au premier lancement.
        SeedData.seedIfNeeded(context: context)
    }

    /// Ouvre la base sur le disque, ou bascule en mémoire si c'est impossible.
    ///
    /// Le dossier « Application Support » n'existe pas dans un conteneur neuf :
    /// CoreData finit par le créer lui-même, mais il logue au passage une longue
    /// erreur de sandbox (« Sandbox access to file-write-create denied ») qui
    /// ressemble à une panne sans en être une. On le crée donc d'avance.
    private static func makeContainer() -> (container: ModelContainer, isEphemeral: Bool) {
        _ = try? FileManager.default.createDirectory(
            at: URL.applicationSupportDirectory,
            withIntermediateDirectories: true
        )

        let onDisk = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, allowsSave: true)
        if let container = try? ModelContainer(for: schema, configurations: onDisk) {
            return (container, false)
        }

        // Une base illisible ne doit jamais empêcher l'app de démarrer :
        // l'utilisateur doit pouvoir ouvrir l'app et exporter ses données.
        // En revanche il doit le savoir — sinon il croirait ses séances
        // enregistrées alors qu'elles disparaissent à la fermeture.
        let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true)
        guard let fallback = try? ModelContainer(for: schema, configurations: inMemory) else {
            fatalError("SwiftData est indisponible, même en mémoire.")
        }
        return (fallback, true)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(sessionViewModel)
                .environment(statsViewModel)
                .environment(\.storageIsEphemeral, storageIsEphemeral)
                .modelContainer(container)
                .task {
                    // Séance laissée en cours lors du dernier lancement.
                    sessionViewModel.restoreInProgressSession()
                }
        }
    }
}
