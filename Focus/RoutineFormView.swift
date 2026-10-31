import SwiftUI
import SwiftData

/// Formulario para crear una rutina nueva o editar una existente.
struct RoutineFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let routine: Routine?   // nil = crear, con valor = editar

    @State private var title: String
    @State private var time: Date
    @State private var weekdays: Set<Int>
    @State private var reminderMinutes: Int
    @State private var category: RoutineCategory
    @State private var isActive: Bool

    // (letra, valor de Calendar): domingo = 1 ... sábado = 7
    private let days: [(String, Int)] = [
        ("L", 2), ("M", 3), ("X", 4), ("J", 5), ("V", 6), ("S", 7), ("D", 1)
    ]

    init(routine: Routine? = nil) {
        self.routine = routine
        _title = State(initialValue: routine?.title ?? "")
        _time = State(initialValue: routine?.startTime ?? .now)
        _weekdays = State(initialValue: Set(routine?.weekdays ?? [2, 3, 4, 5, 6]))
        _reminderMinutes = State(initialValue: routine?.reminderMinutesBefore ?? 10)
        _category = State(initialValue: routine?.category ?? .other)
        _isActive = State(initialValue: routine?.isActive ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rutina") {
                    TextField("Ej. Gym, Estudiar ML, Leer", text: $title)
                    Picker("Categoría", selection: $category) {
                        ForEach(RoutineCategory.allCases) { cat in
                            Label(cat.name, systemImage: cat.icon).tag(cat)
                        }
                    }
                    DatePicker("Hora", selection: $time, displayedComponents: .hourAndMinute)
                }

                Section("Días") {
                    HStack {
                        ForEach(days, id: \.1) { label, value in
                            Button {
                                if weekdays.contains(value) { weekdays.remove(value) }
                                else { weekdays.insert(value) }
                            } label: {
                                Text(label)
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .background(weekdays.contains(value) ? Color.accentColor : Color.gray.opacity(0.2))
                                    .foregroundStyle(weekdays.contains(value) ? .white : .primary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Section("Recordatorio") {
                    Stepper("Avisar \(reminderMinutes) min antes",
                            value: $reminderMinutes, in: 0...120, step: 5)
                }

                if routine != nil {
                    Section {
                        Toggle("Rutina activa", isOn: $isActive)
                    } footer: {
                        Text("Si la pausas, deja de aparecer en Hoy y no te manda notificaciones, pero conservas su historial.")
                    }
                }
            }
            .navigationTitle(routine == nil ? "Nueva rutina" : "Editar rutina")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || weekdays.isEmpty)
                }
            }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)

        if let routine {
            // Editar: cambiamos la plantilla; el historial (logs) no se toca.
            routine.title = cleanTitle
            routine.startTime = time
            routine.weekdays = weekdays.sorted()
            routine.reminderMinutesBefore = reminderMinutes
            routine.category = category
            routine.isActive = isActive
            NotificationManager.schedule(routine)   // cancela las viejas y programa las nuevas
        } else {
            let new = Routine(title: cleanTitle,
                              startTime: time,
                              weekdays: weekdays.sorted(),
                              reminderMinutesBefore: reminderMinutes,
                              category: category)
            context.insert(new)
            NotificationManager.schedule(new)
        }
        dismiss()
    }
}
