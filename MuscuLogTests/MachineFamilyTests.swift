import XCTest
@testable import MuscuLog

/// Vérifie le catalogue de familles de machines et le rattachement d'un nom
/// d'exercice à sa machine (utilisé par la reconnaissance visuelle).
final class MachineFamilyTests: XCTestCase {

    func testCommonMachineNamesResolveToTheirFamily() {
        XCTAssertEqual(MachineFamily.fromExerciseName("Chest press")?.id, "chest-press")
        XCTAssertEqual(MachineFamily.fromExerciseName("Presse à pecs")?.id, "chest-press")
        XCTAssertEqual(MachineFamily.fromExerciseName("Presse à cuisses")?.id, "leg-press")
        XCTAssertEqual(MachineFamily.fromExerciseName("Leg extension")?.id, "leg-extension")
        XCTAssertEqual(MachineFamily.fromExerciseName("Leg curl assis")?.id, "leg-curl")
        XCTAssertEqual(MachineFamily.fromExerciseName("Tirage vertical")?.id, "lat-pulldown")
        XCTAssertEqual(MachineFamily.fromExerciseName("Pec-deck")?.id, "pec-deck")
        XCTAssertEqual(MachineFamily.fromExerciseName("Extensions triceps machine")?.id, "triceps-extension")
        XCTAssertEqual(MachineFamily.fromExerciseName("Abduction à la machine")?.id, "abduction")
    }

    func testMostSpecificFamilyWins() {
        // « Chest press inclinée » doit tomber sur la variante inclinée,
        // pas sur la chest press générique (le synonyme le plus long gagne).
        XCTAssertEqual(
            MachineFamily.fromExerciseName("Chest press inclinée")?.id,
            "inclined-chest-press"
        )
    }

    func testFreeWeightNamesDoNotResolveToMachines() {
        XCTAssertNil(MachineFamily.fromExerciseName("Développé couché"))
        XCTAssertNil(MachineFamily.fromExerciseName("Tractions"))
        XCTAssertNil(MachineFamily.fromExerciseName(""))
    }

    func testSuggestedNameStripsExplanation() {
        let chestPress = MachineFamily.byId("chest-press")
        XCTAssertEqual(chestPress?.suggestedName, "Chest press")
        let legPress = MachineFamily.byId("leg-press")
        XCTAssertEqual(legPress?.suggestedName, "Presse à cuisses")
    }

    func testFamiliesCoverTheMuscleMap() {
        for family in MachineFamily.all {
            XCTAssertFalse(family.muscleGroups.isEmpty, "\(family.id) n'a aucun muscle")
            XCTAssertFalse(family.typicalExercises.isEmpty, "\(family.id) n'a aucun exercice type")
            XCTAssertFalse(family.nameHints.isEmpty, "\(family.id) n'a aucun synonyme")
        }
        // Chaque id est unique.
        let ids = MachineFamily.all.map(\\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testByIdReturnsNilForUnknownIdentifier() {
        XCTAssertNil(MachineFamily.byId("machine-inexistante"))
        XCTAssertNotNil(MachineFamily.byId("shoulder-press"))
    }
}
