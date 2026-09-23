import Vision
import UIKit

/// Reconnaissance visuelle des machines, **sans classifier distant**.
///
/// Principe : Vision extrait un « feature print » (empreinte visuelle) de
/// chaque photo de machine associée à un exercice. Quand l'utilisateur
/// photographie une machine, on la compare aux empreintes connues :
/// reconnaître *sa propre machine* d'une photo à l'autre est fiable.
/// En complément, `VNClassifyImageRequest` tente de reconnaître le **type**
/// d'appareil (chest press, leg press…) — imparfait, mais suffisant pour
/// proposer une famille et ses exercices.
///
/// Architecture : les modèles SwiftData ne sont jamais touchés hors du
/// thread principal. La vue passe un **instantané de valeurs** (`Snapshot`)
/// au recogniser, qui fait tout le travail Vision en arrière-plan et rend
/// des types de valeurs.
enum MachineRecognizer {

    /// Une entrée de bibliothèque figée pour l'analyse (aucun objet SwiftData).
    struct SnapshotEntry {
        let id: UUID
        let name: String
        let image: UIImage
    }

    /// Résultat brut de l'analyse, sans référence SwiftData.
    struct Analysis {
        /// Machine déjà photographiée dont la photo correspond.
        let visualMatchID: UUID?
        /// Confiance du match d'empreinte (0…1). `nil` si pas de match.
        let confidence: Double?
        /// Type d'appareil détecté par Vision, s'il a été identifié.
        let detected: DetectedMachine?
        /// Famille déduite du nom de l'exercice reconnu, sinon de la
        /// détection de type.
        let family: MachineFamily?
    }

    /// Machine reconnue **par type** (étiquette Vision → règle).
    struct DetectedMachine: Equatable {
        let familyID: String
        let title: String
        let muscleGroups: [MuscleGroup]
    }

    /// Tolérance de similarité entre empreintes (1 = identique).
    private static let matchThreshold: Double = 0.75

    // MARK: - Analyse complète

    /// Analyse une photo de machine. Tout le travail Vision tourne hors du
    /// thread principal ; l'appelant (vue, MainActor) n'attend qu'un résultat
    /// de valeurs.
    static func analyze(
        image: UIImage,
        library: [SnapshotEntry],
        excluding: UUID? = nil
    ) async -> Analysis {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let analysis = performAnalysis(image: image, library: library, excluding: excluding)
                continuation.resume(returning: analysis)
            }
        }
    }

    private static func performAnalysis(
        image: UIImage,
        library: [SnapshotEntry],
        excluding: UUID?
    ) -> Analysis {
        // 1. Match d'empreinte : est-ce une machine déjà photographiée ?
        let visual = bestVisualMatch(for: image, in: library, excluding: excluding)

        // 2. Détection du type d'appareil (indépendante du match).
        let detected = detectLabel(in: image)

        // 3. Famille : priorité au nom de l'exercice reconnu (le nom métier
        //    est plus précis que l'étiquette Vision), sinon la détection.
        let family: MachineFamily?
        if let visual, let byName = MachineFamily.fromExerciseName(visual.entry.name) {
            family = byName
        } else if let detected {
            family = MachineFamily.byId(detected.familyID)
        } else {
            family = nil
        }

        return Analysis(
            visualMatchID: visual?.entry.id,
            confidence: visual?.confidence,
            detected: detected,
            family: family
        )
    }

    // MARK: - Empreintes visuelles

    private static func bestVisualMatch(
        for image: UIImage,
        in library: [SnapshotEntry],
        excluding: UUID?
    ) -> (entry: SnapshotEntry, confidence: Double)? {
        guard let queryPrint = try? featurePrint(for: image) else { return nil }

        var best: (entry: SnapshotEntry, confidence: Double)?
        for entry in library where entry.id != excluding {
            guard let storedPrint = try? featurePrint(for: entry.image) else { continue }
            var distance: Float = 0
            do {
                try queryPrint.computeDistance(&distance, to: storedPrint)
            } catch {
                continue
            }
            // Distance 0 = identique ; conversion bornée en score.
            let score = max(0, 1 - Double(distance))
            if score >= matchThreshold, score > (best?.confidence ?? 0) {
                best = (entry, score)
            }
        }
        return best
    }

    static func featurePrint(for image: UIImage) throws -> VNFeaturePrintObservation {
        guard let cgImage = image.cgImage else {
            throw NSError(
                domain: "MachineRecognizer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Image invalide"]
            )
        }
        let request = VNGenerateImageFeaturePrintRequest(options: [:])
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: orientation(of: image),
            options: [:]
        )
        try handler.perform([request])
        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw NSError(
                domain: "MachineRecognizer",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Empreinte non générable"]
            )
        }
        return observation
    }

    // MARK: - Détection de type (Vision)

    /// Tente de reconnaître le **type** d'appareil sur la photo. Vision
    /// propose une taxonomie générique d'objets ; on ne retient que les
    /// étiquettes exploitables, mises en regard des familles.
    private static func detectLabel(in image: UIImage) -> DetectedMachine? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: orientation(of: image),
            options: [:]
        )
        guard (try? handler.perform([request])) != nil,
              let observations = request.results as? [VNClassificationObservation] else {
            return nil
        }
        let labels = observations.filter { $0.confidence > 0.2 }.map(\.identifier)
        return machineLabel(from: labels)
    }

    /// Étiquettes Vision (anglais) → famille de machine.
    private static func machineLabel(from labels: [String]) -> DetectedMachine? {
        let folded = labels.map { $0.lowercased() }

        func hasAny(_ words: [String]) -> Bool {
            words.contains { word in
                folded.contains { $0.contains(word) }
            }
        }

        // Les règles les plus spécifiques d'abord : « bench press » doit
        // tomber sur chest press avant que « press » ne le fasse.
        let rules: [(familyID: String, title: String, words: [String], groups: [MuscleGroup])] = [
            ("lat-pulldown", "Tirage vertical (lat pulldown)", ["pulldown", "pull-up", "pullup", "pull up bar"], [.dos, .biceps]),
            ("seated-row", "Tirage horizontal assis", ["rowing", "rower", "rowing machine"], [.dos, .biceps]),
            ("leg-press", "Presse à cuisses (leg press)", ["leg press", "squat rack"], [.quadriceps, .fessiers]),
            ("leg-extension", "Leg extension", ["leg extension"], [.quadriceps]),
            ("leg-curl", "Leg curl (ischio)", ["leg curl"], [.ischioJambiers]),
            ("pec-deck", "Pec-deck / butterfly", ["butterfly"], [.pectoraux]),
            ("shoulder-press", "Shoulder press (presse à épaules)", ["shoulder press", "shoulder"], [.epaules, .triceps]),
            ("chest-press", "Chest press (presse à pecs)", ["bench", "press bench", "chest press", "dumbbell press"], [.pectoraux, .triceps]),
            ("calf-machine", "Machine à mollets", ["calf", "calves"], [.mollets]),
            ("biceps-curl", "Curl machine", ["bicep", "biceps curl"], [.biceps]),
            ("triceps-extension", "Extension triceps machine", ["tricep", "triceps"], [.triceps]),
            ("abs-crunch", "Machine à abdos (crunch)", ["crunch", "abdominal", "abs"], [.abdominaux]),
        ]

        for rule in rules where hasAny(rule.words) {
            return DetectedMachine(familyID: rule.familyID, title: rule.title, muscleGroups: rule.groups)
        }
        return nil
    }

    private static func orientation(of image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: .up
        case .upMirrored: .upMirrored
        case .down: .down
        case .downMirrored: .downMirrored
        case .left: .left
        case .leftMirrored: .leftMirrored
        case .right: .right
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
