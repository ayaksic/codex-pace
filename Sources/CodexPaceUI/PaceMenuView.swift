import AppKit
import CodexPaceCore
import SwiftUI

public struct PaceMenuView: View {
    @ObservedObject var model: PaceViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding private var isLargeDisplay: Bool
    @State private var isShowingResetEditor = false
    @State private var isShowingBankedResets = false
    @State private var isShowingWeeklyTimeline: Bool
    private let showsDisplaySizeControl: Bool
    private let popOutAction: (() -> Void)?

    public init(
        model: PaceViewModel,
        isLargeDisplay: Binding<Bool>? = nil,
        showsWeeklyTimelineInitially: Bool = true,
        popOutAction: (() -> Void)? = nil
    ) {
        self.model = model
        self._isLargeDisplay = isLargeDisplay ?? .constant(false)
        self._isShowingWeeklyTimeline = State(
            initialValue: showsWeeklyTimelineInitially
        )
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

                Divider()
                versionStatus
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
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("Quit Codex Pace")
            .accessibilityLabel("Quit Codex Pace")
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
        let timelineProgress = WeeklyTimelineProgress(
            window: weeklyWindow,
            at: model.now
        )
        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                isShowingWeeklyTimeline.toggle()
            }
        } label: {
            Group {
                if isShowingWeeklyTimeline {
                    WeeklyTimelineBar(progress: timelineProgress)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 6) {
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
                    .transition(.opacity)
                }
            }
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(
            isShowingWeeklyTimeline
                ? "Show remaining usage and time bars"
                : "Show seven-day usage timeline"
        )
        .accessibilityLabel(
            isShowingWeeklyTimeline
                ? "Seven-day usage timeline"
                : "Usage and time remaining"
        )
        .accessibilityValue(
            isShowingWeeklyTimeline
                ? timelineProgress.accessibilityValue
                : comparisonAccessibilityValue(for: weeklyWindow)
        )
        .accessibilityHint(
            isShowingWeeklyTimeline
                ? "Shows the remaining usage and time bars"
                : "Shows usage consumed across the seven-day window"
        )
    }

    private func comparisonAccessibilityValue(for window: UsageWindow) -> String {
        let usageRemaining = percent(window.usageRemainingPercent, places: 0)
        let timeRemaining = percent(
            window.timeRemainingPercent(at: model.now),
            places: 1
        )
        return "\(usageRemaining) usage remaining, \(timeRemaining) time remaining"
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
                if let projectedRunoutAt = model.projectedRunoutAt,
                   let countdown = model.projectedRunoutCountdownFields {
                    GridRow {
                        detailLabel("Projected runout")
                        durationValue(countdown)
                        timestampSeparator
                        timestampDate(projectedRunoutAt)
                        timestampTime(projectedRunoutAt)
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
                        durationValue(countdown)
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

    private var versionStatus: some View {
        Button {
            Task { await model.checkForUpdates() }
        } label: {
            HStack(spacing: 4) {
                Text(model.appBuildInfo.versionText)
                Text("·")
                Text(model.appBuildInfo.shortRevision)
                    .monospaced()
                Spacer()
                HStack(spacing: 4) {
                    if model.appUpdateStatus == .checking {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: appUpdateStatusSymbol)
                    }
                    Text(model.appUpdateStatusText)
                }
                .foregroundStyle(appUpdateStatusColor)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.appUpdateStatus == .checking)
        .help("Check whether this installed build matches the latest commit on GitHub")
        .accessibilityLabel(
            "Codex Pace \(model.appBuildInfo.versionText), revision "
                + "\(model.appBuildInfo.shortRevision), \(model.appUpdateStatusText)"
        )
    }

    private var appUpdateStatusSymbol: String {
        switch model.appUpdateStatus {
        case .latest:
            "checkmark.circle.fill"
        case .notLatest:
            "arrow.down.circle.fill"
        case .developmentBuild:
            "hammer.circle.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        case .notChecked, .checking:
            "arrow.clockwise.circle"
        }
    }

    private var appUpdateStatusColor: Color {
        switch model.appUpdateStatus {
        case .latest:
            .green
        case .notLatest, .failed:
            .orange
        case .notChecked, .checking, .developmentBuild:
            .secondary
        }
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
        _ fields: DurationFields
    ) -> some View {
        let display = DurationDisplay(fields: fields)
        return HStack(spacing: 5) {
            Text(display.days ?? "")
                .frame(width: 24, alignment: .trailing)
            Text(display.hours ?? "")
                .frame(width: 28, alignment: .trailing)
            Text(display.minutes ?? "")
                .frame(width: 28, alignment: .trailing)
            Text(display.seconds)
                .frame(width: 29, alignment: .trailing)
        }
            .fontWeight(.medium)
            .monospacedDigit()
            .lineLimit(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(display.accessibilityLabel)
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
        guard let state = model.paceMetricState else { return .secondary }
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

struct DurationDisplay {
    let days: String?
    let hours: String?
    let minutes: String?
    let seconds: String
    let accessibilityLabel: String

    init(fields: DurationFields) {
        days = fields.days > 0 ? "\(fields.days)d" : nil
        hours = fields.days > 0 || fields.hours > 0 ? "\(fields.hours)h" : nil
        minutes = fields.days > 0 || fields.hours > 0 || fields.minutes > 0
            ? "\(fields.minutes)m"
            : nil
        seconds = "\(fields.seconds)s"

        let dayText = fields.days > 0 ? "\(fields.days) days" : nil
        let hourText = fields.days > 0 || fields.hours > 0
            ? "\(fields.hours) hours"
            : nil
        let minuteText = fields.days > 0 || fields.hours > 0 || fields.minutes > 0
            ? "\(fields.minutes) minutes"
            : nil
        accessibilityLabel = [
            dayText,
            hourText,
            minuteText,
            "\(fields.seconds) seconds",
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
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

struct WeeklyTimelineProgress: Equatable {
    let usageUsedFraction: Double
    let elapsedFraction: Double

    init(window: UsageWindow, at date: Date) {
        usageUsedFraction = Self.clamp(window.usedPercent / 100)
        elapsedFraction = Self.clamp(
            1 - window.timeRemainingPercent(at: date) / 100
        )
    }

    var accessibilityValue: String {
        let usage = Int((usageUsedFraction * 100).rounded())
        let elapsed = Int((elapsedFraction * 100).rounded())
        return "\(usage)% usage consumed, \(elapsed)% of the window elapsed"
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

private struct WeeklyTimelineBar: View {
    private static let dayCount = 7

    let progress: WeeklyTimelineProgress

    var body: some View {
        HStack(spacing: 7) {
            Text("Week")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
            GeometryReader { proxy in
                let usageWidth = proxy.size.width * progress.usageUsedFraction
                let markerX = proxy.size.width * progress.elapsedFraction

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: usageWidth)
                    Canvas { context, size in
                        let dayWidth = size.width / Double(Self.dayCount)

                        for day in 1..<Self.dayCount {
                            let x = dayWidth * Double(day)
                            var divider = Path()
                            divider.move(to: CGPoint(x: x, y: 0))
                            divider.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(
                                divider,
                                with: .color(.primary.opacity(0.45)),
                                lineWidth: 0.5
                            )
                        }

                        let constrainedMarkerX = min(
                            size.width - 1.5,
                            max(1.5, markerX)
                        )
                        let markerHeight = min(14, size.height - 4)
                        let markerTop = (size.height - markerHeight) / 2
                        var marker = Path()
                        marker.move(
                            to: CGPoint(x: constrainedMarkerX, y: markerTop)
                        )
                        marker.addLine(
                            to: CGPoint(
                                x: constrainedMarkerX,
                                y: markerTop + markerHeight
                            )
                        )
                        context.stroke(
                            marker,
                            with: .color(.white),
                            lineWidth: 3
                        )
                        context.stroke(
                            marker,
                            with: .color(.black),
                            lineWidth: 1
                        )
                    }
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(.primary.opacity(0.22), lineWidth: 0.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
    }
}
