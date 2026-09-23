import Foundation

/// Une **famille de machine** : un type d'appareil que l'on trouve dans la
/// plupart des salles (Fitness Park, Basic-Fit, Keep Cool…), indépendamment
/// de la marque ou du modèle exact.
///
/// La reconnaissance visuelle ne prétend pas distinguer un modèle Technogym
/// d'un modèle Life Fitness : elle classe la photo dans une de ces familles
/// — c'est le niveau qui détermine les exercices à faire dessus.
struct MachineFamily: Identifiable, Equatable {
    let id: String
    /// Nom parlant affiché à l'utilisateur.
    let title: String
    /// Synonymes qui peuvent apparaître dans un nom d'exercice pour rattacher
    /// la famille à la bibliothèque.
    let nameHints: [String]
    let muscleGroups: [MuscleGroup]
    /// Exercices types à faire sur cette machine (noms de la bibliothèque,
    /// en repli si la bibliothèque ne les contient pas encore).
    let typicalExercises: [String]
    /// Si tous les synonymes échouent : où classer la suggestion.
    let fallbackGroup: MuscleGroup

    static func == (lhs: MachineFamily, rhs: MachineFamily) -> Bool { lhs.id == rhs.id }
}

extension MachineFamily {

    /// Machines mainstream : ce qu'un utilisateur trouve quasi toujours.
    /// L'ordre sert au classement en cas d'égalité.
    static let all: [MachineFamily] = [
        // MARK: Pectoraux
        MachineFamily(
            id: "chest-press",
            title: "Chest press (presse à pecs)",
            nameHints: ["chest press", "presse a pecs", "presse pecs", "presse horizontale", "developpe machine"],
            muscleGroups: [.pectoraux, .triceps],
            typicalExercises: ["Développé couché", "Pec-deck"],
            fallbackGroup: .pectoraux
        ),
        MachineFamily(
            id: "inclined-chest-press",
            title: "Chest press inclinée",
            nameHints: ["chest press inclinee", "presse inclinee", "incline press", "developpe incline machine"],
            muscleGroups: [.pectoraux, .epaules],
            typicalExercises: ["Développé incliné", "Pec-deck"],
            fallbackGroup: .pectoraux
        ),
        MachineFamily(
            id: "pec-deck",
            title: "Pec-deck / butterfly",
            nameHints: ["pec deck", "pec-deck", "pecdeck", "butterfly", "ecarte machine", "ecarte a la machine"],
            muscleGroups: [.pectoraux],
            typicalExercises: ["Pec-deck", "Écarté à la poulie"],
            fallbackGroup: .pectoraux
        ),

        // MARK: Dos
        MachineFamily(
            id: "lat-pulldown",
            title: "Tirage vertical (lat pulldown)",
            nameHints: ["tirage vertical", "lat pulldown", "pulldown", "tirage nuque", "tirage poitrine"],
            muscleGroups: [.dos, .biceps],
            typicalExercises: ["Tirage vertical", "Tirage horizontal"],
            fallbackGroup: .dos
        ),
        MachineFamily(
            id: "seated-row",
            title: "Tirage horizontal assis",
            nameHints: ["tirage horizontal", "rowing assis", "rowing machine", "seated row", "tirage assis"],
            muscleGroups: [.dos, .biceps],
            typicalExercises: ["Tirage horizontal", "Rowing barre"],
            fallbackGroup: .dos
        ),

        // MARK: Épaules
        MachineFamily(
            id: "shoulder-press",
            title: "Shoulder press (presse à épaules)",
            nameHints: ["shoulder press", "presse a epaules", "presse epaules", "developpe epaules machine", "developpe militaire machine"],
            muscleGroups: [.epaules, .triceps],
            typicalExercises: ["Développé militaire", "Développé haltères assis"],
            fallbackGroup: .epaules
        ),
        MachineFamily(
            id: "lateral-raise",
            title: "Élévations latérales machine",
            nameHints: ["eleve machine", "elevation laterale machine", "elevations laterales machine", "lateral raise machine", "eleve laterale machine"],
            muscleGroups: [.epaules],
            typicalExercises: ["Élévations latérales", "Élévations latérales poulie"],
            fallbackGroup: .epaules
        ),

        // MARK: Jambes
        MachineFamily(
            id: "leg-press",
            title: "Presse à cuisses (leg press)",
            nameHints: ["leg press", "presse a cuisses", "presse cuisses", "presse jambes"],
            muscleGroups: [.quadriceps, .fessiers],
            typicalExercises: ["Presse à cuisses", "Mollets à la presse"],
            fallbackGroup: .quadriceps
        ),
        MachineFamily(
            id: "leg-extension",
            title: "Leg extension",
            nameHints: ["leg extension", "extension quadriceps", "extension cuisses"],
            muscleGroups: [.quadriceps],
            typicalExercises: ["Leg extension"],
            fallbackGroup: .quadriceps
        ),
        MachineFamily(
            id: "leg-curl",
            title: "Leg curl (ischio)",
            nameHints: ["leg curl", "legcurl", "curl ischio", "ischio machine", "curl jambes"],
            muscleGroups: [.ischioJambiers],
            typicalExercises: ["Leg curl allongé", "Leg curl assis"],
            fallbackGroup: .ischioJambiers
        ),
        MachineFamily(
            id: "hack-squat",
            title: "Hack squat / squat machine",
            nameHints: ["hack squat", "squat machine", "hack squat machine"],
            muscleGroups: [.quadriceps, .fessiers],
            typicalExercises: ["Hack squat", "Squat"],
            fallbackGroup: .quadriceps
        ),
        MachineFamily(
            id: "calf-machine",
            title: "Machine à mollets",
            nameHints: ["mollet machine", "machine a mollets", "calf machine", "mollets debout machine", "pressee mollets"],
            muscleGroups: [.mollets],
            typicalExercises: ["Mollets debout", "Mollets assis"],
            fallbackGroup: .mollets
        ),

        // MARK: Fessiers / abdos
        MachineFamily(
            id: "abduction",
            title: "Machine abduction / adduction",
            nameHints: ["abduction", "adduction", "cuisses interieures", "cuisses externes"],
            muscleGroups: [.fessiers],
            typicalExercises: ["Abduction à la machine"],
            fallbackGroup: .fessiers
        ),
        MachineFamily(
            id: "abs-crunch",
            title: "Machine à abdos (crunch)",
            nameHints: ["machine a abdos", "crunch machine", "abdo machine", "torsion machine"],
            muscleGroups: [.abdominaux],
            typicalExercises: ["Crunch", "Crunch à la poulie"],
            fallbackGroup: .abdominaux
        ),

        // MARK: Bras
        MachineFamily(
            id: "biceps-curl",
            title: "Curl machine",
            nameHints: ["curl machine", "biceps machine", "curl biceps machine", "pupitre machine"],
            muscleGroups: [.biceps],
            typicalExercises: ["Curl pupitre", "Curl à la poulie"],
            fallbackGroup: .biceps
        ),
        MachineFamily(
            id: "triceps-extension",
            title: "Extension triceps machine",
            nameHints: ["extension triceps", "triceps machine", "poussee triceps machine"],
            muscleGroups: [.triceps],
            typicalExercises: ["Extensions triceps poulie", "Barre au front"],
            fallbackGroup: .triceps
        ),
    ]

    /// Nom d'exercice proposé à la création : le libellé sans le
    /// parenthésage explicatif (« Chest press (presse à pecs) » → « Chest press »).
    var suggestedName: String {
        if let range = title.range(of: " (") {
            return String(title[..<range.lowerBound])
        }
        return title
    }

    static func byId(_ id: String) -> MachineFamily? {
        all.first { $0.id == id }
    }

    // MARK: - Rattachement par nom d'exercice

    /// Détecte la famille depuis un nom d'exercice (utiisé par l'empreinte
    /// visuelle : les exercices similaires partagent la machine, donc la
    /// famille). Retourne la famille avec le plus de synonymes trouvés.
    static func fromExerciseName(_ name: String) -> MachineFamily? {
        let folded = name.foldedForSearch
        guard !folded.isEmpty else { return nil }
        var best: (family: MachineFamily, score: Int)?
        for family in all {
            var score = 0
            for hint in family.nameHints where folded.contains(hint) {
                score += hint.count
            }
            if score > 0, score > (best?.score ?? 0) {
                best = (family, score)
            }
        }
        return best?.family
    }
}
