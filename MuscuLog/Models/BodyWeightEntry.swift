import Foundation
import SwiftData

/// Une pesée. Saisie à la main ou importée depuis Santé (optionnel).
@Model
final class BodyWeightEntry {

    var id: UUID = UUID()
    var date: Date = Date()
    var kilograms: Double = 0
    var note: String?
    /// `true` si la valeur provient de Santé, pour éviter les doublons de test.
    var importedFromHealth: Bool = false

    init(date: Date = .now, kilograms: Double, note: String? = nil, importedFromHealth: Bool = false) {
        self.id = UUID()
        self.date = date
        self.kilograms = kilograms
        self.note = note
        self.importedFromHealth = importedFromHealth
    }
}
