import Foundation
import SwiftData

#if HEALTHKIT_ENABLED
import HealthKit
#endif

/// Intégration Santé — **désactivée par défaut**, volontairement.
///
/// HealthKit exige l'entitlement `com.apple.developer.healthkit`, que les
/// comptes Apple ID gratuits ne peuvent pas obtenir : l'activer casserait le
/// sideload avec Sideloadly. Pour l'utiliser :
///
/// 1. compte développeur Apple payant (99 $/an) ;
/// 2. `SWIFT_ACTIVE_COMPILATION_CONDITIONS: HEALTHKIT_ENABLED` dans project.yml ;
/// 3. entitlement HealthKit dans un fichier `.entitlements` référencé par
///    `CODE_SIGN_ENTITLEMENTS`.
///
/// Tant que rien de tout cela n'est fait, toutes les fonctions ci-dessous sont
/// des no-op silencieux : l'app se compile et s'installe normalement.
enum HealthKitService {

    static var isAvailable: Bool {
        #if HEALTHKIT_ENABLED
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "musculog.healthKit") && isAvailable }
        set { UserDefaults.standard.set(newValue, forKey: "musculog.healthKit") }
    }

    // MARK: - Autorisation

    /// Demande l'accès en lecture (poids) et en écriture (séances).
    static func requestAuthorization() async -> Bool {
        #if HEALTHKIT_ENABLED
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let store = HKHealthStore()

        guard
            let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass),
            let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            let workoutType = HKObjectType.workoutType() as HKSampleType?
        else { return false }

        do {
            try await store.requestAuthorization(
                toShare: [workoutType, energy],
                read: [bodyMass]
            )
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: - Écriture d'une séance

    /// Écrit la séance terminée dans l'app Santé comme entraînement de force.
    static func saveWorkout(_ session: WorkoutSession) {
        #if HEALTHKIT_ENABLED
        guard isEnabled else { return }

        let store = HKHealthStore()
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        let start = session.startedAt
        let end = session.endedAt ?? .now
        guard end > start else { return }

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())

        Task {
            do {
                try await builder.beginCollection(at: start)

                // Métadonnées utiles pour retrouver la séance dans Santé.
                let metadata: [String: Any] = [
                    HKMetadataKeyWorkoutBrandName: "MuscuLog",
                    "MuscuLogVolume": session.totalVolume,
                    "MuscuLogSets": session.totalSets,
                    "MuscuLogExercises": session.orderedExercises.map(\.displayName).joined(separator: ", ")
                ]
                try await builder.addMetadata(metadata)

                try await builder.endCollection(at: end)
                _ = try await builder.finishWorkout()
            } catch {
                // On n'alerte pas l'utilisateur : la donnée est déjà locale,
                // un échec HealthKit ne doit jamais faire perdre une séance.
            }
        }
        #endif
    }

    // MARK: - Lecture du poids de corps

    #if HEALTHKIT_ENABLED
    /// Dernière pesée connue dans Santé.
    static func latestBodyMass() async -> (date: Date, kilograms: Double)? {
        guard isAvailable else { return nil }
        let store = HKHealthStore()
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return nil }

        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        let unit = HKUnit.gramUnit(with: .kilo)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: sort) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(
                    returning: (sample.endDate, sample.quantity.doubleValue(for: unit))
                )
            }
            store.execute(query)
        }
    }
    #else
    static func latestBodyMass() async -> (date: Date, kilograms: Double)? { nil }
    #endif
}
