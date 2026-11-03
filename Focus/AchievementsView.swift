import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Query private var routines: [Routine]

    var body: some View {
        let engine = ProgressEngine(routines: routines)
        let achievements = engine.achievements
        let unlocked = achievements.filter { $0.isUnlocked }.count

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        StatCard(title: "Racha actual", value: "\(engine.currentStreak)", unit: "días",
                                 icon: "flame.fill", color: .orange)
                        StatCard(title: "Mejor racha", value: "\(engine.longestStreak)", unit: "días",
                                 icon: "trophy.fill", color: .yellow)
                        StatCard(title: "Días perfectos", value: "\(engine.perfectDays)", unit: "al 100%",
                                 icon: "star.fill", color: .green)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(unlocked) de \(achievements.count) logros")
                            .font(.headline)
                        ProgressView(value: Double(unlocked), total: Double(achievements.count))
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)],
                              spacing: 12) {
                        ForEach(achievements) { achievement in
                            AchievementCard(achievement: achievement)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Logros")
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(achievement.isUnlocked
                            ? achievement.color.gradient
                            : Color.gray.opacity(0.35).gradient,
                            in: Circle())

            Text(achievement.title)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)

            Text(achievement.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if achievement.isUnlocked {
                Label("Logrado", systemImage: "checkmark.seal.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            } else {
                ProgressView(value: achievement.progress)
                    .tint(achievement.color)
                Text("\(achievement.current)/\(achievement.target)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .opacity(achievement.isUnlocked ? 1 : 0.85)
    }
}
