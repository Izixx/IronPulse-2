import Charts
import SwiftUI

// MARK: - Camembert / anneau de répartition musculaire

struct MuscleShareChart: View {
    let stats: [MuscleVolumeStat]

    private var nonEmpty: [MuscleVolumeStat] {
        stats.filter { $0.volume > 0 }.sorted { $0.volume > $1.volume }
    }

    var body: some View {
        VStack(spacing: 12) {
            if nonEmpty.isEmpty {
                EmptyStateView(
                    title: "Aucune donnée",
                    message: "Enregistre une première séance pour voir la répartition de ton volume par muscle.",
                    systemImage: "chart.pie"
                )
            } else {
                Chart(nonEmpty) { stat in
                    SectorMark(
                        angle: .value("Volume", stat.volume),
                        innerRadius: .ratio(0.58),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(stat.group.tint)
                }
                .chartLegend(.hidden)
                .frame(height: 190)
                .overlay {
                    VStack(spacing: 1) {
                        Text("Total")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(nonEmpty.reduce(0) { $0 + $1.volume }.volumeInTonnes)
                            .font(.title3.weight(.bold).monospacedDigit())
                        Text("tonnes")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(nonEmpty) { stat in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(stat.group.tint)
                                .frame(width: 9, height: 9)
                            Text(stat.group.title)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(stat.share(of: nonEmpty.reduce(0) { $0 + $1.volume }).formatted(.percent.precision(.fractionLength(0))))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Barres de volume par muscle

struct MuscleBalanceChart: View {
    let stats: [MuscleVolumeStat]

    private var sorted: [MuscleVolumeStat] {
        stats.sorted { $0.volume > $1.volume }
    }

    var body: some View {
        Chart(sorted) { stat in
            BarMark(
                x: .value("Volume", stat.volume),
                y: .value("Muscle", stat.group.shortTitle)
            )
            .foregroundStyle(stat.group.tint)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let raw = value.as(Double.self) {
                        Text(raw.volumeInTonnes + " t")
                    }
                }
            }
        }
        .chartXScale(domain: 0...(max(sorted.first?.volume ?? 1, 1) * 1.05))
        .frame(height: max(140, CGFloat(sorted.count) * 26))
    }
}

// MARK: - Classement « le plus / le moins travaillé »

/// Lecture immédiate de l'équilibre : les 3 muscles les plus travaillés et les
/// 3 moins travaillés de la période, avec une barre proportionnelle.
struct MuscleRankingList: View {
    let stats: [MuscleVolumeStat]
    var limit: Int = 3

    private var maxVolume: Double { stats.map(\.volume).max() ?? 1 }

    var body: some View {
        let ranked = stats.sorted { $0.volume > $1.volume }
        VStack(spacing: 10) {
            row(title: "Les plus travaillés", items: Array(ranked.prefix(limit)))
            Divider()
            row(title: "Les moins travaillés", items: Array(ranked.suffix(limit).reversed()))
        }
    }

    private func row(title: String, items: [MuscleVolumeStat]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(items) { stat in
                HStack(spacing: 8) {
                    Image(systemName: stat.group.symbolName)
                        .font(.caption)
                        .frame(width: 18)
                        .foregroundStyle(stat.group.tint)

                    Text(stat.group.title)
                        .font(.subheadline)
                        .frame(width: 108, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.tertiarySystemFill))
                            Capsule()
                                .fill(stat.group.tint)
                                .frame(width: max(4, proxy.size.width * ratio(stat)))
                        }
                    }
                    .frame(height: 10)

                    Text("\(stat.volume.volumeInTonnes) t")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .trailing)
                }
            }
        }
    }

    private func ratio(_ stat: MuscleVolumeStat) -> Double {
        maxVolume > 0 ? stat.volume / maxVolume : 0
    }
}

// MARK: - Progression par exercice

enum ProgressMetric: String, CaseIterable, Identifiable {
    case maxWeight
    case estimated1RM
    case volume
    case topReps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .maxWeight: "Charge max"
        case .estimated1RM: "1RM estimé"
        case .volume: "Volume"
        case .topReps: "Répétitions"
        }
    }

    var unit: String {
        switch self {
        case .maxWeight, .estimated1RM: "kg"
        case .volume: "kg"
        case .topReps: "reps"
        }
    }

    func value(_ point: ExerciseProgressPoint) -> Double {
        switch self {
        case .maxWeight: point.maxWeight
        case .estimated1RM: point.estimated1RM
        case .volume: point.volume
        case .topReps: Double(point.topReps)
        }
    }
}

struct ExerciseProgressChart: View {
    let points: [ExerciseProgressPoint]
    let metric: ProgressMetric
    var showArea: Bool = true

    private var tint: Color { metric == .volume ? .teal : .accentColor }

    var body: some View {
        Chart {
            ForEach(points) { point in
                if showArea {
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, metric.value(point))
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [tint.opacity(0.35), tint.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)
                }

                LineMark(
                    x: .value("Date", point.date),
                    y: .value(metric.title, metric.value(point))
                )
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value(metric.title, metric.value(point))
                )
                .foregroundStyle(tint)
                .symbolSize(28)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let raw = value.as(Double.self) {
                        Text(metric == .topReps ? String(Int(raw)) : raw.cleanWeight)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.day().month(.abbreviated)))
                    }
                }
            }
        }
        .chartScrollableAxes(points.count > 12 ? .horizontal : [])
        .frame(height: 200)
    }
}

// MARK: - Heatmap d'assiduité

struct AttendanceHeatmap: View {
    let weeks: [HeatmapWeek]
    var onSelect: ((HeatmapDay) -> Void)?

    private let cell: CGFloat = 12
    private let spacing: CGFloat = 3

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(weeks) { week in
                        VStack(spacing: spacing) {
                            Text(monthLabel(for: week))
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .frame(height: 9)
                                .fixedSize()

                            ForEach(week.days) { day in
                                cellView(day)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                Text("Moins")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color(for: level, isFuture: false))
                        .frame(width: cell, height: cell)
                }
                Text("Plus")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func cellView(_ day: HeatmapDay) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color(for: day.level, isFuture: day.date.startOfDay > Date.now.startOfDay))
            .frame(width: cell, height: cell)
            .overlay {
                if day.date.isToday {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                }
            }
            .onTapGesture {
                onSelect?(day)
            }
            .accessibilityLabel("\(day.date.dayLabel), \(day.sessionCount) séance(s)")
    }

    private func color(for level: Int, isFuture: Bool) -> Color {
        if isFuture { return Color(.tertiarySystemFill).opacity(0.4) }
        switch level {
        case 0: return Color(.tertiarySystemFill)
        case 1: return .accentColor.opacity(0.35)
        case 2: return .accentColor.opacity(0.55)
        case 3: return .accentColor.opacity(0.78)
        default: return .accentColor
        }
    }

    private func monthLabel(for week: HeatmapWeek) -> String {
        // On n'affiche le mois que si la semaine contient le 1er ou le 8,
        // pour éviter 26 étiquettes illisibles.
        let day = calendar.component(.day, from: week.startDate)
        if day <= 7 {
            return week.startDate.formatted(.dateTime.month(.abbreviated))
        }
        return ""
    }
}

// MARK: - Suivi du poids de corps

struct BodyWeightChart: View {
    let entries: [BodyWeightEntry]

    private var sorted: [BodyWeightEntry] {
        entries.sorted { $0.date < $1.date }
    }

    private var minValue: Double { (sorted.map(\.kilograms).min() ?? 0) - 1 }
    private var maxValue: Double { (sorted.map(\.kilograms).max() ?? 100) + 1 }

    var body: some View {
        Chart {
            ForEach(sorted) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Poids", entry.kilograms)
                )
                .foregroundStyle(.indigo)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Poids", entry.kilograms)
                )
                .foregroundStyle(.indigo)
                .symbolSize(30)
            }

            if let average = average {
                RuleMark(y: .value("Moyenne", average))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("moy. \(average.cleanWeight) kg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .chartYScale(domain: minValue...maxValue)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let raw = value.as(Double.self) {
                        Text(raw.cleanWeight)
                    }
                }
            }
        }
        .frame(height: 190)
    }

    private var average: Double? {
        guard !sorted.isEmpty else { return nil }
        return sorted.map(\.kilograms).reduce(0, +) / Double(sorted.count)
    }
}
