import SwiftUI

// MARK: - Carte générique

struct Card<Content: View>: View {
    let title: String?
    let systemImage: String?
    @ViewBuilder let content: () -> Content

    init(title: String? = nil, systemImage: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Label {
                    Text(title).font(.subheadline.weight(.semibold))
                } icon: {
                    if let systemImage {
                        Image(systemName: systemImage).foregroundStyle(.secondary)
                    }
                }
                .labelStyle(.titleAndIcon)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }
}

// MARK: - Tuile de statistique

struct StatTile: View {
    let title: String
    let value: String
    var unit: String?
    var subtitle: String?
    var systemImage: String?
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }
}

// MARK: - Étiquette de groupe musculaire

struct MuscleTag: View {
    let group: MuscleGroup
    var compact: Bool = false

    var body: some View {
        Text(compact ? group.shortTitle : group.title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(group.tint.opacity(0.18), in: .capsule)
            .foregroundStyle(group.tint)
            .lineLimit(1)
    }
}

// MARK: - Champ numérique (kg, reps, RPE…)

/// Champ numérique conçu pour la salle : touches −/+ larges, clavier numérique
/// et saisie libre. Les −/+ évitent d'avoir à sortir le clavier entre deux séries.
struct NumberField: View {
    let title: String
    @Binding var value: Double
    var step: Double = 1
    var unit: String?
    var accent: Color = .accentColor
    var fieldWidth: CGFloat = 44

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 1) {
                stepButton(systemName: "minus", enabled: value > 0) {
                    value = max(0, value - step)
                }

                TextField(title, text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.headline.monospacedDigit())
                    .frame(width: fieldWidth)
                    .focused($isFocused)
                    .onChange(of: text) { _, newValue in
                        let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                        if normalized.isEmpty {
                            value = 0
                        } else if let parsed = Double(normalized) {
                            value = parsed
                        }
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused { text = displayText }
                    }

                stepButton(systemName: "plus", enabled: true) {
                    value += step
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 2)
            .background(accent.opacity(isFocused ? 0.24 : 0.12), in: .rect(cornerRadius: 10))

            Text(unit ?? title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .onAppear { text = displayText }
        .onChange(of: value) { _, _ in
            if !isFocused { text = displayText }
        }
    }

    private var displayText: String {
        value == 0 ? "" : value.cleanWeight
    }

    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap()
        } label: {
            Image(systemName: systemName)
                .font(.footnote.weight(.bold))
                .frame(width: 24, height: 28)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }
}

// MARK: - RPE

struct RPEPicker: View {
    @Binding var rpe: Double?
    var compact: Bool = false

    private let values: [Double] = [6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10]

    var body: some View {
        Menu {
            Button("Pas d'effort ressenti") { rpe = nil }
            Divider()
            ForEach(values, id: \.self) { value in
                Button {
                    rpe = value
                    Haptics.tap()
                } label: {
                    if rpe == value {
                        Label("RPE \(value.cleanWeight)", systemImage: "checkmark")
                    } else {
                        Text("RPE \(value.cleanWeight)")
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "flame")
                    .font(.caption2)
                Text(rpe.map { "RPE \($0.cleanWeight)" } ?? (compact ? "RPE" : "RPE —"))
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                (rpe == nil ? Color.gray : Color.orange).opacity(0.16),
                in: .capsule
            )
            .foregroundStyle(rpe == nil ? Color.secondary : Color.orange)
        }
    }
}

// MARK: - Ligne de navigation

/// Même langage visuel que `BigActionButton`, mais sans `Button` interne :
/// indispensable à l'intérieur d'un `NavigationLink` (un bouton imbriqué
/// intercepterait le tap et la navigation ne partirait jamais).
struct NavRow: View {
    let title: String
    let systemImage: String
    var tint: Color = .accentColor
    var subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.15), in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Sélecteur de période

struct RangePicker: View {
    @Binding var range: StatsRange
    var body: some View {
        Picker("Période", selection: $range) {
            ForEach(StatsRange.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - État vide

struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "tray"
    var action: (title: String, handler: () -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let action {
                Button(action.title, action: action.handler)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 16)
    }
}

// MARK: - Toast

struct ToastView: View {
    let toast: ActiveSessionViewModel.Toast

    private var tint: Color {
        switch toast.kind {
        case .info: .blue
        case .success: .green
        case .warning: .orange
        }
    }

    private var symbol: String {
        switch toast.kind {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(toast.text)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: .capsule)
        .overlay(Capsule().stroke(tint.opacity(0.5), lineWidth: 1))
        .foregroundStyle(tint)
        .shadow(radius: 8, y: 3)
        .padding(.horizontal, 16)
    }
}

// MARK: - Minuteur de repos

/// Barre de repos affichée en permanence pendant la séance.
/// Aucun timer ne tourne : `TimelineView` recalcule l'affichage chaque seconde,
/// ce qui est exact même si l'app a été mise en arrière-plan entre-temps.
struct RestTimerBar: View {
    let endDate: Date
    let total: TimeInterval
    let exerciseName: String?
    let onStop: () -> Void
    let onExtend: (TimeInterval) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, endDate.timeIntervalSince(context.date))
            let progress = total > 0 ? min(1, max(0, (total - remaining) / total)) : 0
            let finished = remaining <= 0

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: finished ? "checkmark.circle.fill" : "hourglass")
                        .foregroundStyle(finished ? .green : .orange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(finished ? "Repos terminé" : DurationFormatter.countdown(remaining))
                            .font(.title3.weight(.bold).monospacedDigit())
                        Text(exerciseName.map { "Repos après \($0)" } ?? "Repos en cours")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("+15 s") { onExtend(15) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("Passer") { onStop() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }

                ProgressView(value: progress)
                    .tint(finished ? .green : .orange)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        }
    }
}

// MARK: - Bouton principal pleine largeur

struct BigActionButton: View {
    let title: String
    let systemImage: String
    var tint: Color = .accentColor
    var subtitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(tint.opacity(0.15), in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
