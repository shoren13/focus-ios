import Foundation
import SwiftUI

/// Resumen de un día: cuántas rutinas tocaban y cuántas cumpliste.
struct DayStat: Identifiable {
    let date: Date
    let scheduled: Int
    let completed: Int

    var id: Date { date }
    var percentage: Double {
        scheduled == 0 ? 0 : Double(completed) / Double(scheduled) * 100
    }
    var isPerfect: Bool { scheduled > 0 && completed == scheduled }
}

/// Un logro desbloqueable. Se calcula al vuelo, no se guarda.
struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let current: Int
    let target: Int

    var isUnlocked: Bool { current >= target }
    var progress: Double { min(Double(current) / Double(target), 1) }
}

/// Única fuente de verdad para "qué tocaba cada día" y "qué cumpliste".
/// Progreso, rachas y logros salen de aquí.
struct ProgressEngine {
    let routines: [Routine]
    var calendar: Calendar = .current

    var today: Date { calendar.startOfDay(for: .now) }

    // MARK: - Base

    /// Rutinas que tocaban ese día (date debe ser inicio de día).
    func scheduledRoutines(on date: Date) -> [Routine] {
        let weekday = calendar.component(.weekday, from: date)
        return routines.filter {
            $0.isActive
            && $0.weekdays.contains(weekday)
            && calendar.startOfDay(for: $0.createdAt) <= date
        }
    }

    func isDone(_ routine: Routine, on date: Date) -> Bool {
        routine.logs.contains { $0.day == date && $0.completed }
    }

    func stat(for date: Date) -> DayStat {
        let scheduled = scheduledRoutines(on: date)
        let done = scheduled.filter { isDone($0, on: date) }
        return DayStat(date: date, scheduled: scheduled.count, completed: done.count)
    }

    /// Todos los días desde que creaste la primera rutina hasta hoy.
    var history: [DayStat] {
        guard let first = routines.map({ $0.createdAt }).min() else { return [] }
        var result: [DayStat] = []
        var date = calendar.startOfDay(for: first)
        let end = today
        while date <= end {
            result.append(stat(for: date))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return result
    }

    // MARK: - Rachas

    /// Días seguidos cumpliendo el 100% de lo que tocaba.
    /// Los días sin rutinas no rompen la racha; hoy no la rompe mientras sigue en curso.
    var currentStreak: Int {
        var streak = 0
        for offset in 0..<365 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let s = stat(for: date)
            if s.scheduled == 0 { continue }
            if s.isPerfect {
                streak += 1
            } else if offset == 0 {
                continue
            } else {
                break
            }
        }
        return streak
    }

    /// La racha más larga que has tenido.
    var longestStreak: Int {
        var best = 0
        var run = 0
        for s in history {
            if s.scheduled == 0 { continue }
            if s.isPerfect {
                run += 1
                best = max(best, run)
            } else if s.date != today {
                run = 0
            }
        }
        return best
    }

    /// Racha de una sola rutina: veces seguidas que la cumpliste en los días que te tocaba.
    func streak(for routine: Routine) -> Int {
        let created = calendar.startOfDay(for: routine.createdAt)
        var count = 0
        for offset in 0..<365 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            if date < created { break }
            let weekday = calendar.component(.weekday, from: date)
            if !routine.weekdays.contains(weekday) { continue }
            if isDone(routine, on: date) {
                count += 1
            } else if offset == 0 {
                continue
            } else {
                break
            }
        }
        return count
    }

    // MARK: - Totales

    var totalCompleted: Int {
        routines.reduce(0) { $0 + $1.logs.filter { $0.completed }.count }
    }

    var perfectDays: Int {
        history.filter { $0.isPerfect }.count
    }

    // MARK: - Logros

    var achievements: [Achievement] {
        let best = max(longestStreak, currentStreak)
        let total = totalCompleted
        let perfect = perfectDays

        return [
            Achievement(id: "first", title: "Primer paso", detail: "Cumple tu primera rutina",
                        icon: "flag.fill", color: .green, current: total, target: 1),
            Achievement(id: "streak3", title: "Calentando motores", detail: "Racha de 3 días",
                        icon: "flame.fill", color: .orange, current: best, target: 3),
            Achievement(id: "streak7", title: "Una semana firme", detail: "Racha de 7 días",
                        icon: "flame.fill", color: .orange, current: best, target: 7),
            Achievement(id: "streak14", title: "Constancia", detail: "Racha de 14 días",
                        icon: "bolt.fill", color: .red, current: best, target: 14),
            Achievement(id: "streak30", title: "Un mes sólido", detail: "Racha de 30 días",
                        icon: "crown.fill", color: .purple, current: best, target: 30),
            Achievement(id: "perfect1", title: "Día perfecto", detail: "Cumple el 100% de un día",
                        icon: "star.fill", color: .yellow, current: perfect, target: 1),
            Achievement(id: "perfect7", title: "Siete días perfectos", detail: "Acumula 7 días al 100%",
                        icon: "star.circle.fill", color: .yellow, current: perfect, target: 7),
            Achievement(id: "total10", title: "En marcha", detail: "Cumple 10 rutinas",
                        icon: "checkmark.circle.fill", color: .blue, current: total, target: 10),
            Achievement(id: "total50", title: "Imparable", detail: "Cumple 50 rutinas",
                        icon: "checkmark.seal.fill", color: .teal, current: total, target: 50),
            Achievement(id: "total100", title: "Centenario", detail: "Cumple 100 rutinas",
                        icon: "medal.fill", color: .indigo, current: total, target: 100)
        ]
    }
}
