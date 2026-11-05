import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @State private var showingAdd = false
    @State private var editingRoutine: Routine?
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }
    private var isToday: Bool { selectedDay == today }

    /// Las reglas de qué tocaba cada día viven en ProgressEngine.
    private var engine: ProgressEngine { ProgressEngine(routines: routines) }

    private var earliestDay: Date? {
        routines.map { $0.createdAt }.min().map { calendar.startOfDay(for: $0) }
    }

    private var canGoBack: Bool {
        guard let earliest = earliestDay else { return false }
        return selectedDay > earliest
    }

    private var dayTitle: String {
        if isToday { return "Hoy" }
        if calendar.isDateInYesterday(selectedDay) { return "Ayer" }
        return selectedDay.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    /// Rutinas que tocaban el día seleccionado, ordenadas por hora.
    private var dayRoutines: [Routine] {
        engine.scheduledRoutines(on: selectedDay)
            .sorted { $0.minutesFromMidnight < $1.minutesFromMidnight }
    }

    /// Rutinas que ese día no tocan o que están pausadas (solo se muestran en "Hoy").
    private var otherRoutines: [Routine] {
        let scheduled = dayRoutines
        return routines
            .filter { r in !scheduled.contains(where: { $0.id == r.id }) }
            .sorted { $0.minutesFromMidnight < $1.minutesFromMidnight }
    }

    private var doneCount: Int { dayRoutines.filter(isDone).count }
    private var allDone: Bool { !dayRoutines.isEmpty && doneCount == dayRoutines.count }
    private var sectionTitle: String { isToday ? "Hoy" : "Rutinas del día" }

    var body: some View {
        NavigationStack {
            List {
                daySelector

                if !dayRoutines.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(allDone ? "¡Día completo!" : "\(doneCount) de \(dayRoutines.count) cumplidas")
                                .font(.headline)
                                .foregroundStyle(allDone ? .green : .primary)
                            ProgressView(value: Double(doneCount),
                                         total: Double(dayRoutines.count))
                                .tint(allDone ? Color.green : Color.accentColor)
                        }
                        .padding(.vertical, 4)
                    }

                    Section(sectionTitle) {
                        ForEach(dayRoutines) { routine in
                            dayRow(routine)
                        }
                        .onDelete { offsets in
                            delete(offsets.map { dayRoutines[$0] })
                        }
                    }

                    Section("Cierre del día") {
                        DayEntryCard(day: selectedDay)
                            .id(selectedDay)
                    }
                } else if !routines.isEmpty {
                    Section {
                        Text(isToday ? "No tienes rutinas programadas para hoy."
                                     : "No tenías rutinas programadas ese día.")
                            .foregroundStyle(.secondary)
                    }
                }

                if isToday && !otherRoutines.isEmpty {
                    Section("Otras rutinas") {
                        ForEach(otherRoutines) { routine in
                            otherRow(routine)
                        }
                        .onDelete { offsets in
                            delete(offsets.map { otherRoutines[$0] })
                        }
                    }
                }
            }
            .overlay {
                if routines.isEmpty {
                    ContentUnavailableView("Sin rutinas",
                                           systemImage: "checklist",
                                           description: Text("Toca + para crear tu primera rutina."))
                }
            }
            .navigationTitle(isToday ? "Hoy" : "Historial")
            .toolbar {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showingAdd) { RoutineFormView() }
            .sheet(item: $editingRoutine) { RoutineFormView(routine: $0) }
            .task {
                await NotificationManager.requestPermission()
                NotificationManager.syncWeeklyReview()
            }
        }
    }

    // MARK: - Selector de día

    private var daySelector: some View {
        Section {
            HStack {
                Button { shiftDay(-1) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(!canGoBack)

                Spacer()

                VStack(spacing: 2) {
                    Text(dayTitle)
                        .font(.headline)
                    if !isToday {
                        Button("Volver a hoy") { selectedDay = today }
                            .font(.caption)
                            .buttonStyle(.borderless)
                    }
                }

                Spacer()

                Button { shiftDay(1) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(isToday)
            }
        }
    }

    private func shiftDay(_ delta: Int) {
        guard let moved = calendar.date(byAdding: .day, value: delta, to: selectedDay) else { return }
        selectedDay = min(calendar.startOfDay(for: moved), today)
    }

    // MARK: - Filas

    private func dayRow(_ routine: Routine) -> some View {
        HStack(spacing: 12) {
            Button { toggle(routine) } label: {
                Image(systemName: isDone(routine) ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isDone(routine) ? .green : .secondary)
            }
            .buttonStyle(.borderless)

            CategoryBadge(category: routine.category)

            VStack(alignment: .leading) {
                Text(routine.title)
                    .strikethrough(isDone(routine))
                Text(routine.startTime, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            // Racha de esta rutina (solo en "Hoy" y desde 2 seguidas)
            if isToday {
                let streak = engine.streak(for: routine)
                if streak >= 2 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { editingRoutine = routine }   // tocar la fila = editar
    }

    private func otherRow(_ routine: Routine) -> some View {
        HStack(spacing: 12) {
            CategoryBadge(category: routine.category)
                .opacity(routine.isActive ? 1 : 0.4)

            VStack(alignment: .leading) {
                Text(routine.title)
                Text("\(routine.weekdaysSummary) · \(routine.startTime.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if !routine.isActive {
                Text("Pausada")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.gray.opacity(0.2), in: Capsule())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { editingRoutine = routine }
    }

    // MARK: - Acciones

    private func isDone(_ routine: Routine) -> Bool {
        routine.logs.contains { $0.day == selectedDay && $0.completed }
    }

    private func toggle(_ routine: Routine) {
        if let log = routine.logs.first(where: { $0.day == selectedDay }) {
            context.delete(log)
        } else {
            context.insert(CompletionLog(day: selectedDay, routine: routine))
        }
    }

    private func delete(_ list: [Routine]) {
        for routine in list {
            NotificationManager.cancel(routine)
            context.delete(routine)
        }
    }
}

/// Circulito de color con el ícono de la categoría.
struct CategoryBadge: View {
    let category: RoutineCategory

    var body: some View {
        Image(systemName: category.icon)
            .font(.subheadline)
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(category.color.gradient, in: Circle())
    }
}
