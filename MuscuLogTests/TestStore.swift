import Foundation
import SwiftData

@testable import MuscuLog

/// Un unique conteneur SwiftData **sur disque**, partagé par tous les tests.
///
/// Pourquoi pas un conteneur en mémoire par test ? Sur iOS 26.5 (Xcode 26.6),
/// la création d'un conteneur en mémoire dans le processus de test fait mourir
/// l'hôte systématiquement (« unexpected exit » dès le premier test qui touche
/// SwiftData, à chaque relance), alors que le conteneur sur disque de l'app
/// hôte fonctionne. On en crée donc un seul, dans un dossier temporaire, et
/// `makeContext()` purge la base avant chaque usage : l'isolation entre tests
/// est conservée sans recréer de conteneur.
@MainActor
enum TestStore {

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

    private static var container: ModelContainer?

    /// Contexte prêt à l'emploi : la base a été vidée juste avant.
    static func makeContext() throws -> ModelContext {
        let container = try sharedContainer()
        try purgeEverything(in: container)
        return container.mainContext
    }

    private static func sharedContainer() throws -> ModelContainer {
        if let container { return container }

        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MuscuLogTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let configuration = ModelConfiguration(
            schema: schema,
            url: directory.appendingPathComponent("tests.sqlite")
        )
        let created = try ModelContainer(for: schema, configurations: configuration)
        container = created
        return created
    }

    private static func purgeEverything(in container: ModelContainer) throws {
        let context = container.mainContext
        // Feuilles d'abord, pour laisser les règles de cascade finir le travail.
        try deleteAll(SetEntry.self, in: context)
        try deleteAll(WorkoutExercise.self, in: context)
        try deleteAll(WorkoutSession.self, in: context)
        try deleteAll(RoutineDayExercise.self, in: context)
        try deleteAll(RoutineDay.self, in: context)
        try deleteAll(Routine.self, in: context)
        try deleteAll(BodyWeightEntry.self, in: context)
        try deleteAll(Exercise.self, in: context)
        try context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) {
            context.delete(model)
        }
    }
}
