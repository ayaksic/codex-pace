import SwiftUI

struct PlannedIdleEditor: View {
    @ObservedObject var model: PaceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hoursText: String

    init(model: PaceViewModel) {
        self.model = model
        _hoursText = State(initialValue: (model.plannedIdleSeconds / 3_600)
            .formatted(.number.precision(.fractionLength(0...2)).grouping(.never)))
    }

    private var hours: Double? {
        guard let value = Double(hoursText.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")),
              value.isFinite, value >= 0,
              value <= model.remainingTargetSeconds / 3_600 else { return nil }
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Planned idle time").font(.headline)
            Text("Subtract time you expect Codex to sit idle before the current reset or expiration target.")
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                TextField("Idle hours remaining", text: $hoursText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .accessibilityLabel("Idle hours remaining")
                Text("hours")
                Spacer()
                ForEach([2, 4, 8], id: \.self) { preset in
                    Button("\(preset)h") { hoursText = String(preset) }
                        .disabled(Double(preset) * 3_600 > model.remainingTargetSeconds)
                }
            }
            if let hours {
                LabeledContent("Active time left") {
                    Text(((model.remainingTargetSeconds / 3_600) - hours)
                        .formatted(.number.precision(.fractionLength(1))) + " hours")
                        .monospacedDigit()
                }
            } else {
                Text("Enter 0 to \((model.remainingTargetSeconds / 3_600).formatted(.number.precision(.fractionLength(2)).rounded(rule: .down))) hours.")
                    .foregroundStyle(.orange)
            }
            Text("Your allowance and reset date stay the same. Pace and bars exclude these hours. Runout assumes this idle time happens before you run out.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("This is a manual estimate of idle time still ahead. Reduce or clear it after your break. It is saved until the usage window or pacing target changes.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if model.plannedIdleSeconds > 0 {
                    Button("Clear") {
                        model.clearPlannedIdleTime()
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    guard let hours else { return }
                    model.setPlannedIdleHours(hours)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(hours == nil)
            }
        }
        .font(.system(size: 13))
        .padding(20)
        .frame(width: 410)
        .onChange(of: model.usageResetCount) { _ in
            // Discard an open draft too, so Save cannot restore last week's hours.
            hoursText = "0"
        }
    }
}
