import SwiftUI
import SwiftData
import Charts

/// Resumen de un día: cuántas rutinas tocaban y cuántas cumpliste.
struct DayStat: Identifiable {
    let date: Date
    let scheduled: Int
    let completed: Int

    var id: Date { date }
    var percentage: Double {
        scheduled == 0 ? 0 : Double(completed) / Double(scheduled) * 100
    }
}

struct StatsView: View {
    @Query private var routines: [Routine]

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    // MARK: - Cálculos

    /// Estadística de un día concreto (date debe ser inicio de día).
    private func stat(for date: Date) -> DayStat {
        let weekday = calendar.component(.weekday, from: date)
        let scheduled = routines.filter {
            $0.isActive
            && $0.weekdays.contains(weekday)
            && calendar.startOfDay(for: $0.createdAt) <= date
        }
        let done = scheduled.filter { routine in
            routine.logs.contains { $0.day == date && $0.completed }
        }
        return DayStat(date: date, scheduled: scheduled.count, completed: done.count)
    }

    /// Últimos 7 días, del más antiguo al de hoy.
    private var weekStats: [DayStat] {
        (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map(stat(for:))
        }
    }

    /// Días seguidos cumpliendo el 100% de lo que tocaba.
    /// Los días sin rutinas no rompen la racha; hoy no la rompe mientras sigue en curso.
    private var currentStreak: Int {
        var streak = 0
        for offset in 0..<365 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let s = stat(for: date)
            if s.scheduled == 0 { continue }
            if s.completed == s.scheduled {
                streak += 1
            } else if offset == 0 {
                continue
            } else {
                break
            }
        }
        return streak
    }

    private var weeklyAverage: Int {
        let active = weekStats.filter { $0.scheduled > 0 }
        guard !active.isEmpty else { return 0 }
        return Int((active.map(\.percentage).reduce(0, +) / Double(active.count)).rounded())
    }

    private var weeklyCompleted: Int {
        weekStats.map(\.completed).reduce(0, +)
    }

    // MARK: - Vista

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        StatCard(title: "Racha", value: "\(currentStreak)", unit: "días", icon: "flame.fill", color: .orange)
                        StatCard(title: "Semana", value: "\(weeklyAverage)", unit: "%", icon: "target", color: .blue)
                        StatCard(title: "Cumplidas", value: "\(weeklyCompleted)", unit: "7 días", icon: "checkmark.seal.fill", color: .green)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cumplimiento, últimos 7 días")
                            .font(.headline)

                        Chart(weekStats) { s in
                            BarMark(
                                x: .value("Día", s.date, unit: .day),
                                y: .value("Cumplimiento", s.percentage)
                            )
                            .foregroundStyle(s.percentage >= 100 ? Color.green : Color.accentColor)
                            .cornerRadius(4)
                        }
                        .chartYScale(domain: 0...100)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisValueLabel(format: .dateTime.weekday(.narrow))
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: [0, 50, 100]) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let v = value.as(Int.self) { Text("\(v)%") }
                                }
                            }
                        }
                        .frame(height: 200)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("Progreso")
        }
    }
}

/// Tarjeta pequeña con un número grande.
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title.bold())
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
