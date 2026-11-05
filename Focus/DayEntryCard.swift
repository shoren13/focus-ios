import SwiftUI
import SwiftData

/// Cierre del día: ánimo del 1 al 5 y una nota corta. Se guarda solo.
struct DayEntryCard: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [DayEntry]
    private let day: Date

    private static let moods = ["😞", "😕", "😐", "🙂", "😄"]
    private static let moodNames = ["Muy mal", "Mal", "Regular", "Bien", "Muy bien"]

    init(day: Date) {
        self.day = day
        _entries = Query(filter: #Predicate<DayEntry> { $0.day == day })
    }

    private var currentMood: Int { entries.first?.mood ?? 0 }

    private var noteBinding: Binding<String> {
        Binding(
            get: { entries.first?.note ?? "" },
            set: { ensureEntry().note = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("¿Cómo te sentiste?")
                .font(.subheadline.bold())

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { value in
                    Button { setMood(value) } label: {
                        Text(Self.moods[value - 1])
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(currentMood == value ? Color.accentColor.opacity(0.25) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Self.moodNames[value - 1])
                }
            }

            TextField("Una nota corta (opcional)", text: noteBinding, axis: .vertical)
                .lineLimit(1...4)
        }
        .padding(.vertical, 4)
    }

    /// Busca la entrada del día y, si no existe, la crea.
    private func ensureEntry() -> DayEntry {
        let target = day
        let descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate<DayEntry> { $0.day == target })
        if let existing = try? context.fetch(descriptor).first { return existing }
        let new = DayEntry(day: day)
        context.insert(new)
        return new
    }

    /// Tocar el mismo ánimo otra vez lo quita.
    private func setMood(_ value: Int) {
        let entry = ensureEntry()
        entry.mood = (entry.mood == value) ? 0 : value
    }
}
