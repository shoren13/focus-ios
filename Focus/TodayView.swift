import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @State private var showingAdd = false
    @State private var editingRoutine: Routine?

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var todayWeekday: Int { Calendar.current.component(.weekday, from: .now) }

    private func isScheduledToday(_ routine: Routine) -> Bool {
        routine.isActive && routine.weekdays.contains(todayWeekday)
    }

    private var todaysRoutines: [Routine] {
        routines
            .filter(isScheduledToday)
            .sorted { $0.minutesFromMidnight < $1.minutesFromMidnight }
    }

    /// Rutinas que hoy no tocan o que están pausadas.
    private var otherRoutines: [Routine] {
        routines
            .filter { !isScheduledToday($0) }
            .sorted { $0.minutesFromMidnight < $1.minutesFromMidnight }
    }

    private var doneCount: Int { todaysRoutines.filter(isDone).count }
    private var allDone: Bool { !todaysRoutines.isEmpty && doneCount == todaysRoutines.count }

    var body: some View {
        NavigationStack {
            List {
                if !todaysRoutines.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(allDone ? "¡Día completo!" : "\(doneCount) de \(todaysRoutines.count) cumplidas")
                                .font(.headline)
                                .foregroundStyle(allDone ? .green : .primary)
                            ProgressView(value: Double(doneCount),
                                         total: Double(todaysRoutines.count))
                                .tint(allDone ? Color.green : Color.accentColor)
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Hoy") {
                        ForEach(todaysRoutines) { routine in
                            todayRow(routine)
                        }
                        .onDelete { offsets in
                            delete(offsets.map { todaysRoutines[$0] })
                        }
                    }
                } else if !routines.isEmpty {
                    Section {
                        Text("No tienes rutinas programadas para hoy.")
                            .foregroundStyle(.secondary)
                    }
                }

                if !otherRoutines.isEmpty {
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
            .navigationTitle("Hoy")
            .toolbar {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showingAdd) { RoutineFormView() }
            .sheet(item: $editingRoutine) { RoutineFormView(routine: $0) }
            .task { await NotificationManager.requestPermission() }
        }
    }

    // MARK: - Filas

    private func todayRow(_ routine: Routine) -> some View {
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
        routine.logs.contains { $0.day == today && $0.completed }
    }

    private func toggle(_ routine: Routine) {
        if let log = routine.logs.first(where: { $0.day == today }) {
            context.delete(log)
        } else {
            context.insert(CompletionLog(day: today, routine: routine))
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
