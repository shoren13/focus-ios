import Foundation
import UserNotifications

/// Se encarga de pedir permiso y programar/cancelar las notificaciones locales.
enum NotificationManager {

    /// Pide permiso al usuario (solo muestra el aviso la primera vez).
    @discardableResult
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    /// Programa una notificación semanal repetida por cada día elegido de la rutina.
    static func schedule(_ routine: Routine) {
        cancel(routine)
        guard routine.isActive else { return }

        // Hora a la que debe sonar = hora de inicio - minutos de aviso.
        var fireMinutes = routine.minutesFromMidnight - routine.reminderMinutesBefore
        var dayShift = 0
        if fireMinutes < 0 {          // si cruza medianoche, cae el día anterior
            fireMinutes += 24 * 60
            dayShift = -1
        }

        let content = UNMutableNotificationContent()
        content.title = routine.title
        content.body = routine.reminderMinutesBefore == 0
            ? "Es hora de empezar."
            : "Empieza en \(routine.reminderMinutesBefore) min."
        content.sound = .default

        for weekday in routine.weekdays {
            var w = weekday + dayShift
            if w < 1 { w = 7 }

            var components = DateComponents()
            components.weekday = w               // 1 = domingo ... 7 = sábado
            components.hour = fireMinutes / 60
            components.minute = fireMinutes % 60

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: identifier(routine, weekday),
                                                content: content,
                                                trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    /// Borra todas las notificaciones pendientes de esa rutina.
    static func cancel(_ routine: Routine) {
        let ids = (1...7).map { identifier(routine, $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Revisión semanal

    private static let weeklyReviewID = "weekly-review"

    /// Programa o cancela el aviso de los domingos según el ajuste del usuario.
    static func syncWeeklyReview() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklyReviewID])

        let enabled = UserDefaults.standard.object(forKey: "weeklyReviewReminder") as? Bool ?? true
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Tu revisión semanal"
        content.body = "Mira cómo te fue esta semana en Focus."
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1     // domingo
        components.hour = 20
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: weeklyReviewID, content: content, trigger: trigger))
    }

    private static func identifier(_ routine: Routine, _ weekday: Int) -> String {
        "\(routine.id.uuidString)-\(weekday)"
    }
}
