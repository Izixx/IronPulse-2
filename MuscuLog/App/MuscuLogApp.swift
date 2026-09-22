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

    init() {
        let container = MuscuLogApp.makeContainer()
        self.container = container

        let context = container.mainContext
        _sessionViewModel = State(initialValue: ActiveSessionViewModel(context: context))

        // Bibliothèque d'exercices + routines types au premier lancement.
        SeedData.seedIfNeeded(context: context)
    }

    private static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Une base illisible ne doit jamais empêcher l'app de démarrer :
            // l'utilisateur doit pouvoir ouvrir l'app et exporter ses données.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true)
            return try! ModelContainer(for: schema, configurations: fallback)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(sessionViewModel)
                .environment(statsViewModel)
                .modelContainer(container)
                .task {
                    // Séance laissée en cours lors du dernier lancement.
                    sessionViewModel.restoreInProgressSession()
                }
        }
    }
}
