import Foundation
import UserNotifications

/// Notifications **locales** uniquement : elles sont programmées sur l'appareil
/// et ne nécessitent ni serveur, ni certificat push, ni compte Apple payant.
enum NotificationService {

    static let restEndIdentifier = "musculog.rest.end"
    static let reminderPrefix = "musculog.reminder."

    // MARK: - Autorisation

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Minuteur de repos

    /// Programme la notification de fin de repos (elle s'affiche même si l'app
    /// est en arrière-plan, ce qui est exactement le cas d'usage).
    static func scheduleRestEnd(after seconds: TimeInterval, exerciseName: String?) {
        cancelRestEnd()
        guard seconds > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Repos terminé 💪"
        content.body = exerciseName.map { "C'est reparti sur \($0)." } ?? "C'est reparti !"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: restEndIdentifier,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelRestEnd() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [restEndIdentifier])
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [restEndIdentifier])
    }

    // MARK: - Rappel d'entraînement

    /// Rappel hebdomadaire répété. `weekdays` suit la convention Apple
    /// (1 = dimanche … 7 = samedi), la valeur par défaut couvre lundi→samedi.
    static func scheduleWorkoutReminder(
        hour: Int,
        minute: Int,
        weekdays: [Int] = [2, 3, 4, 5, 6, 7]
    ) {
        cancelWorkoutReminders()
        guard !weekdays.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Séance du jour ?"
        content.body = "Ouvre MuscuLog pour voir quels muscles sont prêts à travailler."
        content.sound = .default

        for weekday in weekdays {
            var components = DateComponents()
            components.weekday = weekday
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: reminderPrefix + String(weekday),
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancelWorkoutReminders() {
        let identifiers = (1...7).map { reminderPrefix + String($0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
