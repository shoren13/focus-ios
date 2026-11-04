import Foundation
import SwiftData
import SwiftUI

/// Tipos de rutina, cada uno con su ícono y color.
enum RoutineCategory: String, CaseIterable, Identifiable {
    case fitness, study, nutrition, habit, work, other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fitness:   "Ejercicio"
        case .study:     "Estudio"
        case .nutrition: "Nutrición"
        case .habit:     "Hábito"
        case .work:      "Trabajo"
        case .other:     "Otro"
        }
    }

    var icon: String {
        switch self {
        case .fitness:   "figure.run"
        case .study:     "book.fill"
        case .nutrition: "fork.knife"
        case .habit:     "sparkles"
        case .work:      "briefcase.fill"
        case .other:     "circle.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .fitness:   .orange
        case .study:     .indigo
        case .nutrition: .green
        case .habit:     .pink
        case .work:      .blue
        case .other:     .gray
        }
    }
}

/// La "plantilla" de una rutina: qué haces, a qué hora y qué días.
@Model
final class Routine {
    var id: UUID = UUID()
    var title: String
    var startTime: Date              // solo importan hora y minuto
    var weekdays: [Int]              // formato Calendar: 1 = domingo ... 7 = sábado
    var reminderMinutesBefore: Int   // cuántos minutos antes te avisa la noti
    var isActive: Bool
    var createdAt: Date
    var categoryRaw: String = RoutineCategory.other.rawValue
    var pauseStarts: [Date] = []     // cuándo empezó cada pausa
    var pauseEnds: [Date] = []       // cuándo terminó; si falta uno, sigue pausada

    @Relationship(deleteRule: .cascade, inverse: \CompletionLog.routine)
    var logs: [CompletionLog] = []

    init(title: String,
         startTime: Date,
         weekdays: [Int] = [1, 2, 3, 4, 5, 6, 7],
         reminderMinutesBefore: Int = 10,
         category: RoutineCategory = .other) {
        self.title = title
        self.startTime = startTime
        self.weekdays = weekdays
        self.reminderMinutesBefore = reminderMinutesBefore
        self.isActive = true
        self.createdAt = .now
        self.categoryRaw = category.rawValue
    }

    var category: RoutineCategory {
        get { RoutineCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// Para ordenar las rutinas del día por hora.
    var minutesFromMidnight: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Pausa o reactiva la rutina y deja registro de cuándo, para no alterar el pasado.
    func setActive(_ active: Bool, at date: Date = .now) {
        guard active != isActive else { return }
        if active {
            pauseEnds.append(date)
        } else {
            pauseStarts.append(date)
        }
        isActive = active
    }

    /// ¿La rutina estaba activa (no pausada) ese día? date debe ser inicio de día.
    func wasActive(on date: Date, calendar: Calendar = .current) -> Bool {
        for (i, start) in pauseStarts.enumerated() {
            let from = calendar.startOfDay(for: start)
            let until = i < pauseEnds.count ? calendar.startOfDay(for: pauseEnds[i]) : Date.distantFuture
            if date >= from && date < until { return false }
        }
        return true
    }

    /// Texto corto con los días, ej. "L M X J V".
    var weekdaysSummary: String {
        if weekdays.count == 7 { return "Todos los días" }
        let order: [(Int, String)] = [(2, "L"), (3, "M"), (4, "X"), (5, "J"), (6, "V"), (7, "S"), (1, "D")]
        return order.filter { weekdays.contains($0.0) }.map { $0.1 }.joined(separator: " ")
    }
}

/// Un registro por cada día que cumples una rutina. De aquí salen los reportes.
@Model
final class CompletionLog {
    var day: Date          // siempre el inicio del día (00:00)
    var completed: Bool
    var routine: Routine?

    init(day: Date, completed: Bool = true, routine: Routine? = nil) {
        self.day = day
        self.completed = completed
        self.routine = routine
    }
}
