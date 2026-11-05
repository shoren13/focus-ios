import SwiftUI
import SwiftData

/// Resumen de los últimos 7 días comparado con los 7 anteriores.
struct WeeklyReviewView: View {
    @Query private var routines: [Routine]
    @Query private var entries: [DayEntry]
    @AppStorage("weeklyReviewReminder") private var reminderOn = true

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    /// Mismas reglas que Progreso y Logros: todo sale del ProgressEngine.
    private var engine: ProgressEngine { ProgressEngine(routines: routines) }

    // MARK: - Datos

    private struct WeekData {
        let stats: [DayStat]

        var scheduled: Int { stats.map { $0.scheduled }.reduce(0, +) }
        var completed: Int { stats.map { $0.completed }.reduce(0, +) }
        var hasData: Bool { scheduled > 0 }

        /// Promedio de los porcentajes diarios (igual que en la pestaña Progreso).
        var average: Int {
            let active = stats.filter { $0.scheduled > 0 }
            guard !active.isEmpty else { return 0 }
            return Int((active.map { $0.percentage }.reduce(0, +) / Double(active.count)).rounded())
        }
    }

    private struct RoutineResult: Identifiable {
        let routine: Routine
        let scheduled: Int
        let completed: Int

        var id: UUID { routine.id }
        var rate: Double { scheduled == 0 ? 0 : Double(completed) / Double(scheduled) }
    }

    /// weeksAgo = 0 son los últimos 7 días; 1 son los 7 anteriores.
    private func weekData(weeksAgo: Int) -> WeekData {
        let engine = self.engine
        let dates = (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -($0 + 7 * weeksAgo), to: today)
        }
        return WeekData(stats: dates.map { engine.stat(for: $0) })
    }

    /// Cuántas veces cumpliste cada rutina de las que te tocaban esa semana.
    private func routineResults(for week: WeekData) -> [RoutineResult] {
        let engine = self.engine
        let dates = week.stats.map { $0.date }
        return routines.compactMap { routine -> RoutineResult? in
            var scheduled = 0
            var completed = 0
            for date in dates {
                if engine.scheduledRoutines(on: date).contains(where: { $0.id == routine.id }) {
                    scheduled += 1
                    if engine.isDone(routine, on: date) { completed += 1 }
                }
            }
            return scheduled > 0
                ? RoutineResult(routine: routine, scheduled: scheduled, completed: completed)
                : nil
        }
    }

    private func headline(_ current: WeekData, _ last: WeekData) -> String {
        guard current.hasData else { return "Aún no hay datos en los últimos 7 días." }
        guard last.hasData else {
            return "Esta es tu primera semana con datos. Tu punto de partida es \(current.average)%."
        }
        let delta = current.average - last.average
        if delta > 0 { return "Subiste \(delta) puntos respecto a la semana anterior." }
        if delta < 0 { return "Bajaste \(-delta) puntos respecto a la semana anterior." }
        return "Te mantuviste igual que la semana anterior."
    }

    private func dayName(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide)).capitalized
    }

    // MARK: - Vista

    var body: some View {
        let current = weekData(weeksAgo: 0)
        let last = weekData(weeksAgo: 1)
        let results = routineResults(for: current)

        ScrollView {
            VStack(spacing: 20) {
                summaryCard(current: current, last: last, results: results)

                HStack(spacing: 12) {
                    StatCard(title: "Últimos 7 días", value: "\(current.average)", unit: "%",
                             icon: "calendar", color: .blue)
                    StatCard(title: "7 días anteriores",
                             value: last.hasData ? "\(last.average)" : "–",
                             unit: last.hasData ? "%" : "sin datos",
                             icon: "clock.arrow.circlepath", color: .gray)
                }

                daysCard(current: current)
                reinforceCard(results: results)
                moodCard(current: current)

                card {
                    Toggle("Recordarme la revisión los domingos a las 8:00 pm", isOn: $reminderOn)
                        .font(.subheadline)
                }
            }
            .padding()
        }
        .overlay {
            if routines.isEmpty {
                ContentUnavailableView("Aún no hay datos",
                                       systemImage: "calendar",
                                       description: Text("Crea rutinas y cúmplelas para ver tu revisión."))
            }
        }
        .onChange(of: reminderOn) {
            NotificationManager.syncWeeklyReview()
        }
        .navigationTitle("Revisión semanal")
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func summaryCard(current: WeekData, last: WeekData, results: [RoutineResult]) -> some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tu semana")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(headline(current, last))
                    .font(.title3.bold())
                if current.hasData {
                    Text("Cumpliste \(current.completed) de \(current.scheduled) rutinas que te tocaban.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    let perfect = results.filter { $0.completed == $0.scheduled }.count
                    Text("Rutinas al 100%: \(perfect) de \(results.count).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Tu mejor y tu peor día de la semana.
    @ViewBuilder
    private func daysCard(current: WeekData) -> some View {
        let activeDays = current.stats.filter { $0.scheduled > 0 }
        if activeDays.count >= 2,
           let best = activeDays.max(by: { $0.percentage < $1.percentage }),
           let worst = activeDays.min(by: { $0.percentage < $1.percentage }),
           best.percentage != worst.percentage {
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Mejor día: \(dayName(best.date)) (\(Int(best.percentage.rounded()))%)",
                          systemImage: "arrow.up.right.circle.fill")
                        .foregroundStyle(.green)
                    Label("Día más flojo: \(dayName(worst.date)) (\(Int(worst.percentage.rounded()))%)",
                          systemImage: "arrow.down.right.circle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.subheadline)
            }
        }
    }

    private func averageMood(_ values: [Int]) -> String {
        guard !values.isEmpty else { return "–" }
        let avg = Double(values.reduce(0, +)) / Double(values.count)
        return avg.formatted(.number.precision(.fractionLength(1)))
    }

    /// Ánimo promedio de la semana y cómo se relaciona con tus días completos.
    @ViewBuilder
    private func moodCard(current: WeekData) -> some View {
        let moods: [(stat: DayStat, mood: Int)] = current.stats.compactMap { s -> (stat: DayStat, mood: Int)? in
            guard let e = entries.first(where: { $0.day == s.date && $0.mood > 0 }) else { return nil }
            return (stat: s, mood: e.mood)
        }
        if moods.count >= 2 {
            let all = moods.map { $0.mood }
            let perfect = moods.filter { $0.stat.isPerfect }.map { $0.mood }
            let other = moods.filter { !$0.stat.isPerfect && $0.stat.scheduled > 0 }.map { $0.mood }
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Ánimo", systemImage: "face.smiling")
                        .font(.headline)
                    Text("Tu ánimo promedio fue \(averageMood(all)) de 5, en \(moods.count) días registrados.")
                        .font(.subheadline)
                    if perfect.count >= 2 && other.count >= 2 {
                        Text("En tus días al 100% fue \(averageMood(perfect)) y en los incompletos \(averageMood(other)). Es una relación entre datos, no necesariamente una causa.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// La rutina que más se te escapó esta semana.
    @ViewBuilder
    private func reinforceCard(results: [RoutineResult]) -> some View {
        let candidates = results.filter { $0.scheduled >= 2 && $0.completed < $0.scheduled }
        if let weakest = candidates.min(by: { $0.rate < $1.rate }) {
            card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Para reforzar", systemImage: "exclamationmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    HStack(spacing: 12) {
                        CategoryBadge(category: weakest.routine.category)
                        VStack(alignment: .leading) {
                            Text(weakest.routine.title)
                                .font(.subheadline.bold())
                            Text("Cumpliste \(weakest.completed) de \(weakest.scheduled) veces")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Si se te escapa seguido, prueba cambiarla de hora o hacerla más pequeña.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
