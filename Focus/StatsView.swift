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

/// Resumen de una categoría en el periodo elegido.
struct CategoryStat: Identifiable {
    let category: RoutineCategory
    let scheduled: Int
    let completed: Int

    var id: String { category.rawValue }
    var percentage: Double {
        scheduled == 0 ? 0 : Double(completed) / Double(scheduled) * 100
    }
}

/// Periodo que se muestra en los reportes.
enum StatsRange: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30

    var id: Int { rawValue }
    var label: String { self == .week ? "7 días" : "30 días" }
}

struct StatsView: View {
    @Query private var routines: [Routine]
    @State private var range: StatsRange = .week

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    // MARK: - Cálculos

    /// Rutinas que tocaban ese día (date debe ser inicio de día).
    private func scheduledRoutines(on date: Date) -> [Routine] {
        let weekday = calendar.component(.weekday, from: date)
        return routines.filter {
            $0.isActive
            && $0.weekdays.contains(weekday)
            && calendar.startOfDay(for: $0.createdAt) <= date
        }
    }

    private func isDone(_ routine: Routine, on date: Date) -> Bool {
        routine.logs.contains { $0.day == date && $0.completed }
    }

    private func stat(for date: Date) -> DayStat {
        let scheduled = scheduledRoutines(on: date)
        let done = scheduled.filter { isDone($0, on: date) }
        return DayStat(date: date, scheduled: scheduled.count, completed: done.count)
    }

    /// Fechas del periodo, de la más antigua a hoy.
    private var rangeDates: [Date] {
        (0..<range.rawValue).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private var rangeStats: [DayStat] {
        rangeDates.map(stat(for:))
    }

    /// Cumplimiento por categoría en el periodo (solo categorías con rutinas).
    private var categoryStats: [CategoryStat] {
        RoutineCategory.allCases.compactMap { cat in
            var scheduled = 0
            var completed = 0
            for date in rangeDates {
                let list = scheduledRoutines(on: date).filter { $0.category == cat }
                scheduled += list.count
                completed += list.filter { isDone($0, on: date) }.count
            }
            return scheduled > 0
                ? CategoryStat(category: cat, scheduled: scheduled, completed: completed)
                : nil
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

    private var average: Int {
        let active = rangeStats.filter { $0.scheduled > 0 }
        guard !active.isEmpty else { return 0 }
        return Int((active.map(\.percentage).reduce(0, +) / Double(active.count)).rounded())
    }

    private var totalCompleted: Int {
        rangeStats.map(\.completed).reduce(0, +)
    }

    // MARK: - Vista

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Periodo", selection: $range) {
                        ForEach(StatsRange.allCases) { r in
                            Text(r.label).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        StatCard(title: "Racha", value: "\(currentStreak)", unit: "días", icon: "flame.fill", color: .orange)
                        StatCard(title: "Promedio", value: "\(average)", unit: "%", icon: "target", color: .blue)
                        StatCard(title: "Cumplidas", value: "\(totalCompleted)", unit: "\(range.rawValue) días", icon: "checkmark.seal.fill", color: .green)
                    }

                    dailyChart

                    if !categoryStats.isEmpty {
                        categorySection
                    }
                }
                .padding()
            }
            .overlay {
                if routines.isEmpty {
                    ContentUnavailableView("Aún no hay datos",
                                           systemImage: "chart.bar",
                                           description: Text("Crea rutinas en Hoy y aquí verás tu progreso."))
                }
            }
            .navigationTitle("Progreso")
        }
    }

    private var dailyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cumplimiento, últimos \(range.rawValue) días")
                .font(.headline)

            Chart(rangeStats) { s in
                BarMark(
                    x: .value("Día", s.date, unit: .day),
                    y: .value("Cumplimiento", s.percentage)
                )
                .foregroundStyle(s.percentage >= 100 ? Color.green : Color.accentColor)
                .cornerRadius(4)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 7)) { _ in
                    AxisValueLabel(format: range == .week
                                   ? Date.FormatStyle.dateTime.weekday(.narrow)
                                   : Date.FormatStyle.dateTime.day().month(.abbreviated))
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

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Por categoría")
                .font(.headline)

            ForEach(categoryStats.sorted { $0.percentage > $1.percentage }) { s in
                HStack(spacing: 12) {
                    CategoryBadge(category: s.category)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(s.category.name)
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(s.completed)/\(s.scheduled) · \(Int(s.percentage.rounded()))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: s.percentage, total: 100)
                            .tint(s.category.color)
                    }
                }
            }

            insight
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    /// Resalta tu área más fuerte y la que más necesita atención.
    @ViewBuilder
    private var insight: some View {
        if categoryStats.count >= 2,
           let best = categoryStats.max(by: { $0.percentage < $1.percentage }),
           let worst = categoryStats.min(by: { $0.percentage < $1.percentage }),
           best.percentage != worst.percentage {
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Label("Más fuerte: \(best.category.name) (\(Int(best.percentage.rounded()))%)",
                      systemImage: "arrow.up.right.circle.fill")
                    .foregroundStyle(.green)
                Label("A reforzar: \(worst.category.name) (\(Int(worst.percentage.rounded()))%)",
                      systemImage: "arrow.down.right.circle.fill")
                    .foregroundStyle(.orange)
            }
            .font(.subheadline)
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
