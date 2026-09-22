import UIKit

/// Retour haptique : en salle, on regarde l'écran du bout des doigts,
/// une petite vibration confirme la saisie sans avoir à vérifier.
@MainActor
enum Haptics {

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "musculog.haptics") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "musculog.haptics") }
    }

    static func tap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func thump() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
