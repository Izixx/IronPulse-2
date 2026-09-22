import Foundation

// MARK: - 1RM estimé

/// Estimation de la charge maximale théorique (1RM) à partir d'une série.
///
/// On utilise **Epley** (`poids × (1 + reps / 30)`), la formule la plus
/// répandue : simple, stable et fiable jusqu'à ~10-12 répétitions.
/// Au-delà l'estimation devient optimiste, c'est précisé dans l'interface.
enum OneRepMax {

    /// Nombre de répétitions au-delà duquel l'estimation n'est plus fiable.
    static let reliableRepRange = 1...12

    static func estimate(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30)
    }

    /// Formule de Brzycki, gardée pour comparaison.
    static func brzycki(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0, reps < 37 else { return 0 }
        return weight * 36 / (37 - Double(reps))
    }

    /// Charge à viser pour un nombre de répétitions donné, d'après un 1RM.
    static func weight(forReps reps: Int, from oneRM: Double) -> Double {
        guard reps > 0, oneRM > 0 else { return 0 }
        if reps == 1 { return oneRM }
        return oneRM / (1 + Double(reps) / 30)
    }
}

// MARK: - Formatage des nombres

extension Double {

    /// « 80 » plutôt que « 80.0 », « 82,5 » plutôt que « 82.5 ».
    var cleanWeight: String {
        formatted(.number.precision(.fractionLength(0...2)))
    }

    /// Volume / tonnage : séparateur de milliers, pas de décimales.
    var cleanVolume: String {
        formatted(.number.precision(.fractionLength(0)).grouping(.automatic))
    }

    /// Volume en tonnes, compact pour les cartes de statistiques.
    var volumeInTonnes: String {
        let tonnes = self / 1000
        if tonnes < 10 {
            return tonnes.formatted(.number.precision(.fractionLength(0...1)))
        }
        return tonnes.formatted(.number.precision(.fractionLength(0)).grouping(.automatic))
    }

    var cleanInt: String {
        formatted(.number.precision(.fractionLength(0)).grouping(.automatic))
    }
}

extension Int {
    var cleanInt: String { Double(self).cleanInt }
}

// MARK: - Dates

extension Date {

    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    /// Nombre de jours calendaires écoulés depuis cette date (0 = aujourd'hui).
    var daysSince: Int {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: self)
        let to = calendar.startOfDay(for: .now)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    var daysSinceDouble: Double {
        max(0, Date.now.timeIntervalSince(self) / 86_400)
    }

    var isToday: Bool { Calendar.current.isDateInToday(self) }

    var dayLabel: String {
        formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var shortDayLabel: String {
        formatted(.dateTime.day().month(.abbreviated))
    }

    var monthLabel: String {
        formatted(.dateTime.month(.wide).year())
    }
}

// MARK: - Durées

enum DurationFormatter {

    /// « 1 h 12 » ou « 47 min »
    static func workout(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 { return "\(hours) h \(String(format: "%02d", minutes))" }
        return "\(minutes) min"
    }

    /// « 1:30 » pour le minuteur de repos.
    static func countdown(_ interval: TimeInterval) -> String {
        let clamped = max(0, interval)
        let minutes = Int(clamped) / 60
        let seconds = Int(clamped) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Couleurs et échelles

enum HeatmapScale {

    /// 5 paliers d'intensité, comme le calendrier de contributions GitHub.
    static func level(for count: Int) -> Int {
        switch count {
        case ..<1: 0
        case 1: 1
        case 2: 2
        case 3: 3
        default: 4
        }
    }
}
