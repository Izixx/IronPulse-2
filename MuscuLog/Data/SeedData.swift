import Foundation
import SwiftData

/// Bibliothèque d'exercices livrée avec l'app, plus quelques routines types.
/// Tout est modifiable et supprimable : ce n'est qu'un point de départ.
enum SeedData {

    struct Seed {
        let name: String
        let groups: [MuscleGroup]
        let equipment: String?
    }

    static let exercises: [Seed] = [
        // MARK: Pectoraux
        Seed(name: "Développé couché", groups: [.pectoraux, .triceps, .epaules], equipment: "Barre"),
        Seed(name: "Développé incliné", groups: [.pectoraux, .epaules], equipment: "Barre"),
        Seed(name: "Développé décliné", groups: [.pectoraux], equipment: "Barre"),
        Seed(name: "Développé couché haltères", groups: [.pectoraux, .triceps], equipment: "Haltères"),
        Seed(name: "Développé incliné haltères", groups: [.pectoraux, .epaules], equipment: "Haltères"),
        Seed(name: "Écarté couché haltères", groups: [.pectoraux], equipment: "Haltères"),
        Seed(name: "Écarté à la poulie", groups: [.pectoraux], equipment: "Poulie"),
        Seed(name: "Pec-deck", groups: [.pectoraux], equipment: "Machine"),
        Seed(name: "Pompes", groups: [.pectoraux, .triceps], equipment: "Poids du corps"),

        // MARK: Dos
        Seed(name: "Soulevé de terre", groups: [.dos, .fessiers, .ischioJambiers], equipment: "Barre"),
        Seed(name: "Rowing barre", groups: [.dos, .biceps], equipment: "Barre"),
        Seed(name: "Rowing haltère un bras", groups: [.dos, .biceps], equipment: "Haltère"),
        Seed(name: "Tirage vertical", groups: [.dos, .biceps], equipment: "Poulie"),
        Seed(name: "Tirage horizontal", groups: [.dos, .biceps], equipment: "Poulie"),
        Seed(name: "Tractions", groups: [.dos, .biceps], equipment: "Poids du corps"),
        Seed(name: "Tractions assistées", groups: [.dos, .biceps], equipment: "Machine"),
        Seed(name: "Pull-over", groups: [.dos, .pectoraux], equipment: "Haltère"),
        Seed(name: "Shrugs", groups: [.epaules, .dos], equipment: "Haltères"),
        Seed(name: "Rowing T-bar", groups: [.dos], equipment: "Machine"),

        // MARK: Épaules
        Seed(name: "Développé militaire", groups: [.epaules, .triceps], equipment: "Barre"),
        Seed(name: "Développé haltères assis", groups: [.epaules, .triceps], equipment: "Haltères"),
        Seed(name: "Développé Arnold", groups: [.epaules], equipment: "Haltères"),
        Seed(name: "Élévations latérales", groups: [.epaules], equipment: "Haltères"),
        Seed(name: "Élévations frontales", groups: [.epaules], equipment: "Haltères"),
        Seed(name: "Oiseau", groups: [.epaules, .dos], equipment: "Haltères"),
        Seed(name: "Face pull", groups: [.epaules, .dos], equipment: "Poulie"),
        Seed(name: "Élévations latérales poulie", groups: [.epaules], equipment: "Poulie"),

        // MARK: Biceps
        Seed(name: "Curl barre EZ", groups: [.biceps], equipment: "Barre EZ"),
        Seed(name: "Curl haltères", groups: [.biceps], equipment: "Haltères"),
        Seed(name: "Curl marteau", groups: [.biceps], equipment: "Haltères"),
        Seed(name: "Curl incliné", groups: [.biceps], equipment: "Haltères"),
        Seed(name: "Curl pupitre", groups: [.biceps], equipment: "Barre EZ"),
        Seed(name: "Curl à la poulie", groups: [.biceps], equipment: "Poulie"),

        // MARK: Triceps
        Seed(name: "Barre au front", groups: [.triceps], equipment: "Barre EZ"),
        Seed(name: "Extensions triceps poulie", groups: [.triceps], equipment: "Poulie"),
        Seed(name: "Extension nuque haltère", groups: [.triceps], equipment: "Haltère"),
        Seed(name: "Dips", groups: [.triceps, .pectoraux], equipment: "Poids du corps"),
        Seed(name: "Développé couché prise serrée", groups: [.triceps, .pectoraux], equipment: "Barre"),
        Seed(name: "Kickback haltère", groups: [.triceps], equipment: "Haltère"),
        Seed(name: "Dips entre bancs", groups: [.triceps], equipment: "Poids du corps"),

        // MARK: Quadriceps
        Seed(name: "Squat", groups: [.quadriceps, .fessiers], equipment: "Barre"),
        Seed(name: "Front squat", groups: [.quadriceps], equipment: "Barre"),
        Seed(name: "Presse à cuisses", groups: [.quadriceps, .fessiers], equipment: "Machine"),
        Seed(name: "Leg extension", groups: [.quadriceps], equipment: "Machine"),
        Seed(name: "Fentes marchées", groups: [.quadriceps, .fessiers], equipment: "Haltères"),
        Seed(name: "Squat gobelet", groups: [.quadriceps], equipment: "Haltère"),
        Seed(name: "Hack squat", groups: [.quadriceps], equipment: "Machine"),

        // MARK: Ischio-jambiers
        Seed(name: "Soulevé de terre roumain", groups: [.ischioJambiers, .fessiers, .dos], equipment: "Barre"),
        Seed(name: "Leg curl allongé", groups: [.ischioJambiers], equipment: "Machine"),
        Seed(name: "Leg curl assis", groups: [.ischioJambiers], equipment: "Machine"),
        Seed(name: "Good morning", groups: [.ischioJambiers, .dos], equipment: "Barre"),
        Seed(name: "Nordic curl", groups: [.ischioJambiers], equipment: "Poids du corps"),

        // MARK: Fessiers
        Seed(name: "Hip thrust", groups: [.fessiers], equipment: "Barre"),
        Seed(name: "Fentes bulgares", groups: [.fessiers, .quadriceps], equipment: "Haltères"),
        Seed(name: "Abduction à la machine", groups: [.fessiers], equipment: "Machine"),
        Seed(name: "Pont fessier", groups: [.fessiers], equipment: "Poids du corps"),
        Seed(name: "Kickback fessier poulie", groups: [.fessiers], equipment: "Poulie"),

        // MARK: Mollets
        Seed(name: "Mollets debout", groups: [.mollets], equipment: "Machine"),
        Seed(name: "Mollets assis", groups: [.mollets], equipment: "Machine"),
        Seed(name: "Mollets à la presse", groups: [.mollets], equipment: "Machine"),
        Seed(name: "Mollets une jambe haltère", groups: [.mollets], equipment: "Haltère"),

        // MARK: Abdominaux
        Seed(name: "Crunch", groups: [.abdominaux], equipment: "Poids du corps"),
        Seed(name: "Crunch à la poulie", groups: [.abdominaux], equipment: "Poulie"),
        Seed(name: "Relevé de jambes suspendu", groups: [.abdominaux], equipment: "Poids du corps"),
        Seed(name: "Gainage", groups: [.abdominaux], equipment: "Poids du corps"),
        Seed(name: "Roulette abdominale", groups: [.abdominaux], equipment: "Accessoire"),
        Seed(name: "Russian twist", groups: [.abdominaux], equipment: "Haltère")
    ]

    // MARK: - Amorçage

    /// Insère la bibliothèque de départ si la base est vide.
    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard existing == 0 else { return }

        var byName: [String: Exercise] = [:]
        for seed in exercises {
            let exercise = Exercise(
                name: seed.name,
                muscleGroups: seed.groups,
                equipment: seed.equipment,
                isCustom: false
            )
            context.insert(exercise)
            byName[seed.name] = exercise
        }

        seedRoutines(context: context, byName: byName)
        try? context.save()
    }

    struct RoutineTemplate {
        let name: String
        let days: [(name: String, exercises: [(String, Int, Int)])]
    }

    static let routineTemplates: [RoutineTemplate] = [
        RoutineTemplate(name: "Push / Pull / Legs", days: [
            ("Push", [
                ("Développé couché", 4, 8),
                ("Développé incliné haltères", 3, 10),
                ("Développé militaire", 3, 8),
                ("Élévations latérales", 3, 15),
                ("Extensions triceps poulie", 3, 12)
            ]),
            ("Pull", [
                ("Soulevé de terre", 3, 5),
                ("Tractions", 3, 8),
                ("Rowing barre", 3, 10),
                ("Face pull", 3, 15),
                ("Curl barre EZ", 3, 10)
            ]),
            ("Legs", [
                ("Squat", 4, 8),
                ("Soulevé de terre roumain", 3, 10),
                ("Presse à cuisses", 3, 12),
                ("Leg curl allongé", 3, 12),
                ("Mollets debout", 4, 15)
            ])
        ]),
        RoutineTemplate(name: "Haut / Bas du corps", days: [
            ("Haut du corps", [
                ("Développé couché", 4, 8),
                ("Rowing barre", 4, 8),
                ("Développé militaire", 3, 10),
                ("Tractions", 3, 8),
                ("Curl barre EZ", 3, 10),
                ("Extensions triceps poulie", 3, 12)
            ]),
            ("Bas du corps", [
                ("Squat", 4, 8),
                ("Soulevé de terre roumain", 3, 10),
                ("Fentes marchées", 3, 12),
                ("Leg curl allongé", 3, 12),
                ("Mollets debout", 4, 15)
            ])
        ]),
        RoutineTemplate(name: "Full body", days: [
            ("Full body A", [
                ("Squat", 4, 8),
                ("Développé couché", 4, 8),
                ("Rowing barre", 3, 10),
                ("Gainage", 3, 45)
            ]),
            ("Full body B", [
                ("Soulevé de terre", 3, 5),
                ("Développé militaire", 3, 8),
                ("Tractions", 3, 8),
                ("Mollets debout", 4, 15)
            ])
        ])
    ]

    @MainActor
    private static func seedRoutines(context: ModelContext, byName: [String: Exercise]) {
        for template in routineTemplates {
            let routine = Routine(name: template.name, isActive: false)
            context.insert(routine)

            for (dayIndex, dayTemplate) in template.days.enumerated() {
                let day = RoutineDay(name: dayTemplate.name, order: dayIndex)
                context.insert(day)
                routine.attach(day)

                for (index, item) in dayTemplate.exercises.enumerated() {
                    let entry = RoutineDayExercise(
                        exercise: byName[item.0],
                        order: index,
                        targetSets: item.1,
                        targetReps: item.2
                    )
                    context.insert(entry)
                    day.attach(entry)
                }
            }
        }
    }
}
