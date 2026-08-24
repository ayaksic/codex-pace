import AppKit
import CodexPaceCore
import SwiftUI

public struct PaceMenuView: View {
    @ObservedObject var model: PaceViewModel
    @Binding private var isLargeDisplay: Bool
    @State private var isShowingResetEditor = false
    @State private var isShowingBankedResets = false
    private let showsDisplaySizeControl: Bool
    private let popOutAction: (() -> Void)?

    public init(
        model: PaceViewModel,
        isLargeDisplay: Binding<Bool>? = nil,
        popOutAction: (() -> Void)? = nil
    ) {
        self.model = model
        self._isLargeDisplay = isLargeDisplay ?? .constant(false)
        self.showsDisplaySizeControl = isLargeDisplay != nil
        self.popOutAction = popOutAction
    }

    public var body: some View {
        ScaledLayout(scale: displayScale) {
            VStack(spacing: 10) {
                header

                if let snapshot = model.snapshot {
                    metrics(snapshot)
                    comparison(snapshot)
                    details(snapshot)
                } else {
                    unavailable
                }

                if model.availableBankedResetCount > 0 {
                    Divider()
                    bankedResets
                }
            }
            .padding(12)
            .frame(width: 412)
            .scaleEffect(displayScale, anchor: .topLeading)
        }
        .sheet(isPresented: $isShowingResetEditor) {
            ResetOverrideEditor(model: model)
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Spacer()
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.75)
            }
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh usage")
            .disabled(model.isRefreshing)
            Button {
                isShowingResetEditor = true
            } label: {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(model.isManualResetActive ? Color.accentColor : .primary)
            }
            .buttonStyle(.plain)
            .help(model.isManualResetActive ? "Edit reset estimate" : "Set reset estimate")
            .accessibilityLabel(
                model.isManualResetActive ? "Edit reset estimate" : "Set reset estimate"
            )
            if showsDisplaySizeControl {
                Button {
                    isLargeDisplay.toggle()
                } label: {
                    Text(isLargeDisplay ? "1×" : "2×")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.plain)
                .help(isLargeDisplay ? "Use standard window size" : "Double window size")
                .accessibilityLabel(
                    isLargeDisplay ? "Use standard window size" : "Double window size"
                )
            }
            if let popOutAction {
                Button(action: popOutAction) {
                    Image(systemName: "macwindow")
                }
                .buttonStyle(.plain)
                .help("Open Codex Pace window")
                .accessibilityLabel("Open Codex Pace window")
            }
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("Quit Codex Pace")
            .accessibilityLabel("Quit Codex Pace")
        }
        .frame(maxWidth: .infinity)
    }

    private func metrics(_ snapshot: PaceSnapshot) -> some View {
        let weeklyWindow = model.effectiveWeeklyWindow ?? snapshot.weeklyWindow
        return HStack(spacing: 0) {
            MetricView(
                label: "Week left",
                value: percent(weeklyWindow.timeRemainingPercent(at: model.now), places: 1)
            )
            Divider()
                .frame(height: 35)
                .padding(.horizontal, 8)
            MetricView(
                label: "Usage left",
                value: percent(weeklyWindow.usageRemainingPercent, places: 0)
            )
            Divider()
                .frame(height: 35)
                .padding(.horizontal, 8)
            MetricView(
                label: model.paceMetricLabel,
                value: model.paceMetricValue ?? "—",
                color: headerColor
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func comparison(_ snapshot: PaceSnapshot) -> some View {
        let weeklyWindow = model.effectiveWeeklyWindow ?? snapshot.weeklyWindow
        return VStack(spacing: 6) {
            ComparisonBar(
                label: "Usage",
                value: weeklyWindow.usageRemainingPercent,
                color: .accentColor
            )
            ComparisonBar(
                label: "Time",
                value: weeklyWindow.timeRemainingPercent(at: model.now),
                color: .purple
            )
        }
    }

    private func details(_ snapshot: PaceSnapshot) -> some View {
        VStack(spacing: 6) {
            Grid(alignment: .leading, horizontalSpacing: 5, verticalSpacing: 6) {
                if let paceTimeLabel = model.paceTimeLabel,
                   let paceTime = model.paceTimeFields {
                    GridRow {
                        detailLabel(paceTimeLabel)
                        durationValue(paceTime)
                        if let stoppageEndsAt = model.stoppageEndsAt {
                            timestampSeparator
                            timestampDate(stoppageEndsAt)
                            timestampTime(stoppageEndsAt)
                        } else {
                            timestampSeparatorPlaceholder
                            timestampDatePlaceholder
                            timestampTimePlaceholder
                        }
                    }
                }
                if let resetTarget = model.resetCountdownTarget {
                    GridRow {
                        detailLabel(resetLabel(for: resetTarget.kind))
                        durationValue(
                            model.remainingTimeFields(until: resetTarget.date)
                        )
                        timestampSeparator
                        timestampDate(resetTarget.date)
                        timestampTime(resetTarget.date)
                    }
                }
                if let nextRefreshAt = model.nextRefreshAt,
                   let countdown = model.nextRefreshCountdownFields {
                    GridRow {
                        detailLabel("Next update")
                        durationValue(countdown, hidesZeroMinutes: true)
                        timestampSeparator
                        timestampDate(nextRefreshAt)
                        timestampTime(nextRefreshAt)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.callout)
    }

    private var bankedResets: some View {
        VStack(spacing: 6) {
            Button {
                withAnimation {
                    isShowingBankedResets.toggle()
                }
            } label: {
                HStack {
                    Text("Banked resets")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(model.availableBankedResetCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isShowingBankedResets ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Banked resets, \(model.availableBankedResetCount)")
            .accessibilityValue(isShowingBankedResets ? "Expanded" : "Collapsed")

            if isShowingBankedResets {
                Grid(alignment: .leading, horizontalSpacing: 5, verticalSpacing: 6) {
                    ForEach(model.availableBankedResetCredits) { credit in
                        GridRow {
                            detailLabel("Expires")
                            if let expiresAt = credit.expiresAt {
                                durationValue(model.remainingTimeFields(until: expiresAt))
                                timestampSeparator
                                timestampDate(expiresAt)
                                timestampTime(expiresAt)
                            } else {
                                Text("No expiration reported")
                                    .foregroundStyle(.secondary)
                                    .gridCellColumns(4)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if model.bankedResetCountWithoutDetails > 0 {
                    Text(expirationDetailsUnavailableText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .font(.callout)
    }

    private var unavailable: some View {
        VStack(spacing: 7) {
            if model.isRefreshing {
                Text("Reading Codex usage…")
                    .foregroundStyle(.secondary)
            } else {
                Text("Usage unavailable")
                    .fontWeight(.medium)
                Text(model.errorMessage ?? "Refresh to try again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72)
    }

    private func percent(_ value: Double, places: Int) -> String {
        value.formatted(.number.precision(.fractionLength(places))) + "%"
    }

    private func resetLabel(for kind: ResetCountdownKind) -> String {
        switch kind {
        case .natural:
            "Resets"
        case .manualEstimate:
            "Reset by (est.)"
        case .bankedResetExpiry:
            "Banked reset expires"
        }
    }

    private var expirationDetailsUnavailableText: String {
        let count = model.bankedResetCountWithoutDetails
        let noun = count == 1 ? "reset" : "resets"
        return "Expiration details unavailable for \(count) additional \(noun)."
    }

    private func detailLabel(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(width: 106, alignment: .leading)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }

    private func durationValue(
        _ fields: DurationFields,
        hidesZeroMinutes: Bool = false
    ) -> some View {
        HStack(spacing: 5) {
            Text(fields.days == 0 ? "" : "\(fields.days)d")
                .frame(width: 24, alignment: .trailing)
            Text(fields.hours == 0 ? "" : "\(fields.hours)h")
                .frame(width: 28, alignment: .trailing)
            Text(hidesZeroMinutes && fields.minutes == 0 ? "" : "\(fields.minutes)m")
                .frame(width: 28, alignment: .trailing)
            Text("\(fields.seconds)s")
                .frame(width: 29, alignment: .trailing)
        }
            .fontWeight(.medium)
            .monospacedDigit()
            .lineLimit(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                durationAccessibilityLabel(fields, hidesZeroMinutes: hidesZeroMinutes)
            )
    }

    private func durationAccessibilityLabel(
        _ fields: DurationFields,
        hidesZeroMinutes: Bool
    ) -> String {
        let dayText = fields.days == 0 ? nil : "\(fields.days) days"
        let hourText = fields.hours == 0 ? nil : "\(fields.hours) hours"
        let minuteText = hidesZeroMinutes && fields.minutes == 0
            ? nil
            : "\(fields.minutes) minutes"
        return [dayText, hourText, minuteText, "\(fields.seconds) seconds"]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func timestampDate(_ value: Date) -> some View {
        Text(value.formatted(
            .dateTime
                .month(.abbreviated)
                .day(.twoDigits)
                .locale(Locale(identifier: "en_US_POSIX"))
        ))
        .monospacedDigit()
        .frame(width: 44, alignment: .leading)
    }

    private func timestampTime(_ value: Date) -> some View {
        Text(value.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .abbreviated))
                .minute(.twoDigits)
                .second(.twoDigits)
                .locale(Locale(identifier: "en_US_POSIX"))
        ))
        .monospacedDigit()
        .frame(width: 88, alignment: .leading)
    }

    private var timestampSeparator: some View {
        Text("•")
            .frame(width: 5, alignment: .center)
    }

    private var timestampDatePlaceholder: some View {
        Color.clear.frame(width: 44, height: 1)
    }

    private var timestampTimePlaceholder: some View {
        Color.clear.frame(width: 88, height: 1)
    }

    private var timestampSeparatorPlaceholder: some View {
        Color.clear.frame(width: 5, height: 1)
    }

    private var headerColor: Color {
        guard let state = model.currentPaceState else { return .secondary }
        return statusColor(state)
    }

    private var displayScale: CGFloat {
        isLargeDisplay ? 2 : 1
    }

    private func statusColor(_ state: PaceState) -> Color {
        switch state {
        case .ahead, .onPace:
            .green
        case .behind:
            .orange
        }
    }
}

private struct ResetOverrideEditor: View {
    @ObservedObject var model: PaceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date

    init(model: PaceViewModel) {
        self.model = model
        let earliestDate = model.now.addingTimeInterval(60)
        let initialDate = model.manualResetAt
            ?? model.snapshot?.weeklyWindow.resetsAt
            ?? model.now.addingTimeInterval(3_600)
        _selectedDate = State(initialValue: max(earliestDate, initialDate))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reset estimate")
                .font(.headline)

            Text("Use this for a one-off reset expected before Codex's reported seven-day window ends.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DatePicker(
                "Estimated reset by",
                selection: $selectedDate,
                in: model.now.addingTimeInterval(60)...,
                displayedComponents: [.date, .hourAndMinute]
            )

            if let reportedResetAt = model.snapshot?.weeklyWindow.resetsAt {
                LabeledContent("Codex reports") {
                    Text(reportedResetAt.formatted(date: .abbreviated, time: .shortened))
                        .monospacedDigit()
                }
                .font(.callout)
            }

            Text("This changes the displayed reset countdown only. Week left and pace continue to use the window reported by Codex. Times use this Mac's time zone.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if model.isManualResetActive {
                    Button("Remove estimate", role: .destructive) {
                        model.clearManualReset()
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    model.setManualResetAt(dateRoundedToMinute(selectedDate))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 390)
    }

    private func dateRoundedToMinute(_ date: Date) -> Date {
        let components = Calendar.current.dateComponents(
            [.calendar, .timeZone, .year, .month, .day, .hour, .minute],
            from: date
        )
        return Calendar.current.date(from: components) ?? date
    }
}

private struct ScaledLayout: Layout {
    let scale: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        let contentSize = subview.sizeThatFits(
            ProposedViewSize(
                width: proposal.width.map { $0 / scale },
                height: proposal.height.map { $0 / scale }
            )
        )
        return CGSize(width: contentSize.width * scale, height: contentSize.height * scale)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else { return }
        subview.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: bounds.width / scale,
                height: bounds.height / scale
            )
        )
    }
}

private struct MetricView: View {
    let label: String
    let value: String
    var color: Color?

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color ?? .primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(color ?? .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ComparisonBar: View {
    private static let segmentCount = 20

    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * min(100, max(0, value)) / 100)
                    Canvas { context, size in
                        let segmentWidth = size.width / Double(Self.segmentCount)
                        let fillWidth = size.width * min(100, max(0, value)) / 100

                        for tick in 1..<Self.segmentCount {
                            let x = segmentWidth * Double(tick)
                            let tickColor: Color = x <= fillWidth
                                ? .black
                                : .white.opacity(0.85)
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(
                                path,
                                with: .color(tickColor),
                                lineWidth: 0.5
                            )
                        }
                    }
                    .mask(Capsule())
                }
            }
            .frame(height: 5)
        }
    }
}
