import AppKit
import CodexPaceCore
import SwiftUI

public struct PaceMenuView: View {
    @ObservedObject var model: PaceViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding private var isLargeDisplay: Bool
    @State private var isShowingCreditEditor = false
    @State private var isShowingBuildDetails = false
    @State private var isShowingResetEditor = false
    @State private var isShowingWeeklyTimeline: Bool
    private let showsDisplaySizeControl: Bool
    private let popOutAction: (() -> Void)?
    private let maximumHeight: CGFloat
    private let scaleOverride: CGFloat?

    public init(
        model: PaceViewModel,
        isLargeDisplay: Binding<Bool>? = nil,
        showsWeeklyTimelineInitially: Bool = false,
        maximumHeight: CGFloat = .infinity,
        displayScale: CGFloat? = nil,
        popOutAction: (() -> Void)? = nil
    ) {
        self.model = model
        self._isLargeDisplay = isLargeDisplay ?? .constant(false)
        self._isShowingWeeklyTimeline = State(
            initialValue: showsWeeklyTimelineInitially
        )
        self.showsDisplaySizeControl = isLargeDisplay != nil
        self.popOutAction = popOutAction
        self.maximumHeight = maximumHeight
        self.scaleOverride = displayScale
    }

    public var body: some View {
        responsiveContent
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: PaceContentSizeKey.self, value: geometry.size)
                }
            }
            .sheet(isPresented: $isShowingCreditEditor) {
                CreditExpirationEditor(model: model)
            }
            .sheet(isPresented: $isShowingResetEditor) {
                ResetOverrideEditor(model: model)
            }
    }

    @ViewBuilder private var responsiveContent: some View {
        if maximumHeight.isInfinite {
            scaledContent(presentsBuildDetails: true)
        } else {
            BoundedContentLayout(maximumHeight: maximumHeight) {
                // The measurement copy must never share presentation ownership
                // with the visible copy: dismissing its hidden popover also
                // dismissed the real popover on the next model/timer update.
                scaledContent(presentsBuildDetails: false).hidden().accessibilityHidden(true)
                ScrollView(.vertical) {
                    scaledContent(presentsBuildDetails: true)
                }
            }
        }
    }

    private func scaledContent(presentsBuildDetails: Bool) -> some View {
        ScaledLayout(scale: displayScale) {
            VStack(spacing: PaceMenuLayout.groupGap) {
                PaceToolbarLayout {
                    header(presentsBuildDetails: presentsBuildDetails)
                }
                if let snapshot = model.snapshot {
                    metrics(snapshot)
                    comparison(snapshot)
                } else {
                    unavailable
                }
                VStack(spacing: PaceMenuLayout.groupGap) {
                    if let snapshot = model.snapshot { details(snapshot) }
                    usageCredits
                    if model.availableBankedResetCount > 0 { bankedResets }
                    if model.snapshot != nil, let error = model.errorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(PaceColors.warning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, PaceMenuLayout.horizontalPadding)
            .padding(.vertical, PaceMenuLayout.groupGap)
            .frame(width: PaceMenuLayout.width)
            .scaleEffect(displayScale, anchor: .topLeading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: PaceNaturalContentSizeKey.self,
                    value: PaceNaturalMeasurement(size: geometry.size, hasReading: model.snapshot != nil))
            }
        }
    }

    private func header(presentsBuildDetails: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "xmark.circle")
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
            versionStatus(presentsBuildDetails: presentsBuildDetails)
            Spacer()
            if let countdown = model.nextRefreshCountdownFields {
                Text(DurationDisplay(fields: countdown).compactText)
                    .font(Font.system(size: 11))
                    .foregroundStyle(PaceColors.secondary)
                    .monospacedDigit()
                    .help(model.nextRefreshAt.map { "Next update: \($0.formatted(date: .abbreviated, time: .complete))" } ?? "")
            }
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
                        .font(Font.system(size: 12, weight: .medium))
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
        .padding(.horizontal, PaceMenuLayout.barInset)
        .frame(maxWidth: .infinity)
    }

    private func metrics(_ snapshot: PaceSnapshot) -> some View {
        let weeklyWindow = model.effectiveWeeklyWindow ?? snapshot.weeklyWindow
        return PaceColumns {
            MetricView(label: "Usage left", value: percent(weeklyWindow.usageRemainingPercent, places: 0),
                       color: PaceColors.usage)
        } middle: {
            MetricView(label: model.timeRemainingLabel,
                       value: percent(weeklyWindow.timeRemainingPercent(at: model.now), places: 1),
                       color: PaceColors.time)
                .overlay(alignment: .leading) { metricDivider }
        } trailing: {
            MetricView(label: model.paceMetricLabel, value: model.paceMetricValue ?? "—", color: headerColor)
                .overlay(alignment: .leading) { metricDivider }
        }
    }

    private var metricDivider: some View {
        Rectangle().fill(PaceColors.secondary.opacity(0.2)).frame(width: 1)
            .offset(x: -PaceMenuLayout.columnGap / 2)
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
                    VStack(spacing: PaceMenuLayout.pairGap) {
                        ComparisonBar(
                            value: weeklyWindow.usageRemainingPercent,
                            color: PaceColors.usage,
                            contentScale: displayScale
                        )
                        ComparisonBar(
                            value: weeklyWindow.timeRemainingPercent(at: model.now),
                            color: PaceColors.time,
                            contentScale: displayScale
                        )
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: PaceMenuLayout.comparisonHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, PaceMenuLayout.barInset)
        .help(
            isShowingWeeklyTimeline
                ? "Show remaining usage and time bars"
                : model.timelineDescription
        )
        .accessibilityLabel(
            isShowingWeeklyTimeline
                ? model.timelineDescription
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
                : model.timelineDescription
        )
    }

    private func comparisonAccessibilityValue(for window: UsageWindow) -> String {
        let usageRemaining = percent(window.usageRemainingPercent, places: 0)
        let timeRemaining = percent(
            window.timeRemainingPercent(at: model.now),
            places: 1
        )
        return "\(usageRemaining) usage remaining, \(timeRemaining) time remaining. \(model.timelineDescription)"
    }

    private func details(_: PaceSnapshot) -> some View {
        VStack(spacing: PaceMenuLayout.groupGap) {
            if let label = model.paceTimeLabel, let fields = model.paceTimeFields {
                PaceColumns {
                    detailLabel(label == "Stoppage time" ? "Stop until" : label)
                } middle: { durationValue(fields) } trailing: { detailTimestamp(model.stoppageEndsAt) }
            }
            if let date = model.projectedRunoutAt, let fields = model.projectedRunoutCountdownFields {
                PaceColumns { detailLabel("Run out at") } middle: {
                    durationValue(fields)
                } trailing: { detailTimestamp(date) }
            }
            ForEach(model.visibleResetCountdownTargets, id: \.date) { target in
                PaceColumns { detailLabel(resetLabel(for: target.kind)) } middle: {
                    durationValue(model.remainingTimeFields(until: target.date))
                } trailing: { detailTimestamp(target.date) }
            }
        }
    }

    private var usageCredits: some View {
        PaceColumns {
            VStack(spacing: PaceMenuLayout.groupGap) {
                detailLabel(model.compactUsageCreditBalanceText.map { "\($0) credits" } ?? "Credits unavailable")
                if model.usageCreditReadingLabel == "Last known balance" {
                    PaceInkText(value: "Last known", font: .systemFont(ofSize: 11))
                        .foregroundStyle(PaceColors.secondary)
                }
            }
            .help("\(model.usageCreditReadingLabel): \(model.usageCreditBalanceText)")
        } middle: {
            if let date = model.creditExpirationAt { durationValue(model.remainingTimeFields(until: date)) }
        } trailing: {
            Button { isShowingCreditEditor = true } label: {
                if let date = model.creditExpirationAt {
                    detailTimestamp(date)
                } else {
                    PaceInkText(value: "Set expiration")
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit credit expiration date")
            .help(model.creditExpirationAt.map {
                "Expires at the start of the selected date: \($0.formatted(date: .complete, time: .complete))"
            } ?? "Set the credit expiration date")
        }
    }

    private var bankedResets: some View {
        VStack(spacing: PaceMenuLayout.groupGap) {
            ForEach(model.availableBankedResetCredits) { credit in
                PaceColumns { detailLabel("Banked reset") } middle: {
                    if let date = credit.expiresAt { durationValue(model.remainingTimeFields(until: date)) }
                    else { PaceInkText(value: "—") }
                } trailing: {
                    if let date = credit.expiresAt { detailTimestamp(date) }
                    else { PaceInkText(value: "No expiry reported", font: .systemFont(ofSize: 12))
                        .foregroundStyle(PaceColors.secondary) }
                }
            }
            if model.bankedResetCountWithoutDetails > 0 {
                Text(expirationDetailsUnavailableText)
                    .font(.system(size: 12)).foregroundStyle(PaceColors.secondary)
                    .frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var unavailable: some View {
        VStack(spacing: PaceMenuLayout.groupGap) {
            if model.isRefreshing {
                Text("Reading Codex usage…")
                    .foregroundStyle(PaceColors.secondary)
            } else {
                Text("Usage unavailable")
                    .fontWeight(.medium)
                Text(model.errorMessage ?? "Refresh to try again.")
                    .font(Font.system(size: 12))
                    .foregroundStyle(PaceColors.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func versionStatus(presentsBuildDetails: Bool) -> some View {
        Button {
            isShowingBuildDetails.toggle()
            if isShowingBuildDetails { Task { await model.checkForUpdates() } }
        } label: {
            HStack(spacing: 8) {
                Text(model.appBuildInfo.version)
                Image(systemName: appUpdateStatusSymbol)
                    .foregroundStyle(appUpdateStatusColor)
            }
            .font(Font.system(size: 11))
            .foregroundStyle(PaceColors.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Build details and update check")
        .accessibilityLabel(
            "Codex Pace \(model.appBuildInfo.versionText), revision "
                + "\(model.appBuildInfo.shortRevision), \(model.appUpdateStatusText). Show build details."
        )
        .popover(isPresented: presentsBuildDetails ? $isShowingBuildDetails : .constant(false)) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Codex Pace \(model.appBuildInfo.version)")
                    .font(Font.system(size: 14, weight: .medium))
                Text("Build \(model.appBuildInfo.build) · \(model.appBuildInfo.shortRevision)")
                    .foregroundStyle(PaceColors.secondary)
                    .textSelection(.enabled)
                Button(model.appUpdateStatus == .checking ? "Checking…" : "Check for updates") {
                    Task { await model.checkForUpdates() }
                }
                .disabled(model.appUpdateStatus == .checking)
                Text(model.appUpdateStatusText)
                    .foregroundStyle(appUpdateStatusColor)
            }
            .font(Font.system(size: 12))
            .padding(16)
        }
    }

    private var appUpdateStatusSymbol: String {
        switch model.appUpdateStatus {
        case .latest:
            "checkmark.circle"
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
            PaceColors.success
        case .notLatest, .failed:
            PaceColors.warning
        case .notChecked, .checking, .developmentBuild:
            PaceColors.secondary
        }
    }

    private func percent(_ value: Double, places: Int) -> String {
        value.formatted(.number.precision(.fractionLength(places))) + "%"
    }

    private func resetLabel(for kind: ResetCountdownKind) -> String {
        switch kind {
        case .natural:
            "Reset at"
        case .manualEstimate:
            "Reset by (est.)"
        case .bankedResetExpiry:
            "Reset expiry"
        }
    }

    private var expirationDetailsUnavailableText: String {
        let count = model.bankedResetCountWithoutDetails
        let noun = count == 1 ? "reset" : "resets"
        return "Expiration details unavailable for \(count) additional \(noun)."
    }

    private func detailLabel(_ text: String) -> some View {
        PaceInkText(value: text).foregroundStyle(Color.primary)
            .lineLimit(1)
    }

    private func durationValue(_ fields: DurationFields) -> some View {
        AlignedCountdown(fields: fields)
    }

    private func detailTimestamp(_ value: Date?) -> some View {
        Group {
            if let value {
                AlignedTimestamp(date: value)
            } else { PaceInkText(value: "") }
        }
        .font(PaceTypography.rowFont).foregroundStyle(Color.primary)
        .monospacedDigit().lineLimit(1)
        .help(value.map { $0.formatted(date: .complete, time: .complete) } ?? "")
    }

    private var headerColor: Color {
        guard let state = model.paceMetricState else { return PaceColors.secondary }
        return statusColor(state)
    }

    private var displayScale: CGFloat {
        scaleOverride ?? (isLargeDisplay ? 2 : 1)
    }

    private func statusColor(_ state: PaceState) -> Color {
        switch state {
        case .ahead, .onPace:
            PaceColors.success
        case .behind:
            PaceColors.warning
        }
    }
}

struct CreditExpirationEditor: View {
    @ObservedObject var model: PaceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var dateText: String

    init(model: PaceViewModel) {
        self.model = model
        _dateText = State(initialValue: model.creditExpirationNote?.isoDate ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expiration date").font(Font.system(size: 15, weight: .medium))
            TextField("Date (YYYY-MM-DD)", text: $dateText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Expiration date, YYYY-MM-DD")
            Text("A manually entered date for some usage credits. Codex reports their total balance here, without individual expiration dates.")
                .font(Font.system(size: 12)).foregroundStyle(PaceColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if model.creditExpirationNote != nil {
                    Button("Remove expiration date", role: .destructive) {
                        model.removeCreditExpirationNote()
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    if let note = CreditExpirationNote(dateText) {
                        model.setCreditExpirationNote(note)
                        dismiss()
                    }
                }
                .disabled(CreditExpirationNote(dateText) == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .font(Font.system(size: 13))
        .padding(20)
        .frame(width: 380)
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
                .font(Font.system(size: 15, weight: .medium))

            Text("Use this for a one-off reset expected before Codex's reported seven-day window ends.")
                .font(Font.system(size: 13))
                .foregroundStyle(PaceColors.secondary)
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
                .font(Font.system(size: 13))
            }

            Text("Time left, bars and pace target the earliest of this estimate, a banked reset expiration, or the weekly reset. Percentages use a seven-day scale. Times use this Mac's time zone.")
                .font(Font.system(size: 12))
                .foregroundStyle(PaceColors.secondary)
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
        .font(Font.system(size: 13))
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

public struct PaceContentSizeKey: PreferenceKey {
    public static let defaultValue: CGSize = .zero
    public static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 0, next.height > 0 {
            value = next
        }
    }
}

struct PaceNaturalMeasurement: Equatable {
    var size: CGSize = .zero
    var hasReading = false
}

struct PaceNaturalContentSizeKey: PreferenceKey {
    static let defaultValue = PaceNaturalMeasurement()
    static func reduce(value: inout PaceNaturalMeasurement, nextValue: () -> PaceNaturalMeasurement) {
        let next = nextValue()
        if next.size.width > 0, next.size.height > 0 { value = next }
    }
}

// Measure the full content independently of the current window proposal. Grow
// with disclosure rows, then scroll once the display's available height is used.
private struct BoundedContentLayout: Layout {
    let maximumHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let natural = subviews[0].sizeThatFits(.unspecified)
        return CGSize(width: natural.width, height: min(natural.height, maximumHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: .unspecified)
        subviews[1].place(at: bounds.origin, anchor: .topLeading,
                          proposal: ProposedViewSize(bounds.size))
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
                height: nil
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
                height: nil
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

    var compactText: String {
        [days, hours, minutes, seconds].compactMap { $0 }.joined(separator: " ")
    }

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

struct PaceColumns<Leading: View, Middle: View, Trailing: View>: View {
    let leading: Leading
    let middle: Middle
    let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder middle: () -> Middle,
         @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading(); self.middle = middle(); self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PaceMenuLayout.columnGap) {
            ZStack(alignment: Alignment(horizontal: .center, vertical: .firstTextBaseline)) {
                Color.clear.frame(width: 0, height: 0); leading
            }
                .frame(width: PaceMenuLayout.labelWidth)
            ZStack(alignment: Alignment(horizontal: .center, vertical: .firstTextBaseline)) {
                Color.clear.frame(width: 0, height: 0); middle
            }
                .frame(width: PaceMenuLayout.countdownWidth)
            ZStack(alignment: Alignment(horizontal: .center, vertical: .firstTextBaseline)) {
                Color.clear.frame(width: 0, height: 0); trailing
            }
                .frame(width: PaceMenuLayout.dateWidth)
        }
        .frame(minHeight: PaceMenuLayout.rowHeight)
    }
}

/// Center the common h/m/s block; the optional day prefix never shifts its unit columns.
struct AlignedCountdown: View {
    let fields: DurationFields

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PaceMenuLayout.durationGap) {
            part(fields.days > 0 ? padded(fields.hours) : String(fields.hours), unit: "h")
                .opacity(display.hours == nil ? 0 : 1)
            part(display.hours == nil ? String(fields.minutes) : padded(fields.minutes), unit: "m")
                .opacity(display.minutes == nil ? 0 : 1)
            part(display.minutes == nil ? String(fields.seconds) : padded(fields.seconds), unit: "s")
        }
        .overlay(alignment: .leading) {
            if fields.days > 0 {
                part(String(fields.days), unit: "d")
                    .offset(x: -PaceMenuLayout.durationPartWidth - PaceMenuLayout.durationGap)
            }
        }
        .offset(x: PaceMenuLayout.countdownOffset)
        .font(PaceTypography.rowFont).monospacedDigit().lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(display.accessibilityLabel)
    }

    private var display: DurationDisplay { DurationDisplay(fields: fields) }
    private func padded(_ value: Int) -> String { String(format: "%02d", value) }
    private func part(_ number: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            PaceInkText(value: number, monospacedDigits: true).fixedSize()
                .frame(width: PaceMenuLayout.durationNumberWidth, alignment: .trailing)
            PaceInkText(value: unit).frame(width: PaceMenuLayout.durationUnitWidth, alignment: .leading)
        }
    }
}

private struct MetricView: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: PaceMenuLayout.pairGap) {
            PaceInkText(value: value, font: PaceTypography.metricNativeFont(size: 34), tracking: 0.5,
                        lineReference: PaceTypography.metricLineReference)
                .foregroundStyle(color)
            Text(label.lowercased()).font(.system(size: 10, weight: .medium)).foregroundStyle(color)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Capsule().fill(color.opacity(0.17)))
        }
        .frame(maxWidth: .infinity)
    }
}

enum ComparisonBarGeometry {
    static let segmentCount = 50

    static func ticks(width: CGFloat, pixelScale: CGFloat) -> [CGFloat] {
        let scale = max(1, pixelScale)
        return (1..<segmentCount).map { index in
            (floor(width * CGFloat(index) / CGFloat(segmentCount) * scale) + 0.5) / scale
        }
    }
}

private struct ComparisonBar: View {
    @Environment(\.displayScale) private var backingScale

    let value: Double
    let color: Color
    let contentScale: CGFloat

    var body: some View {
        Group {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * min(100, max(0, value)) / 100)
                    Canvas { context, size in
                        let pixelScale = max(1, backingScale * contentScale)
                        let fillWidth = size.width * min(100, max(0, value)) / 100

                        for x in ComparisonBarGeometry.ticks(width: size.width, pixelScale: pixelScale) {
                            let tickColor: Color = x <= fillWidth
                                ? .black
                                : .white.opacity(0.85)
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(
                                path,
                                with: .color(tickColor),
                                lineWidth: 1 / pixelScale
                            )
                        }
                    }
                    .mask(Capsule())
                }
            }
            .frame(height: PaceMenuLayout.barHeight)
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

struct WeeklyTimelineBar: View {
    private static let dayCount = 7

    let progress: WeeklyTimelineProgress

    var body: some View {
        Group {
            GeometryReader { proxy in
                let usageWidth = proxy.size.width * progress.usageUsedFraction
                let markerX = proxy.size.width * progress.elapsedFraction

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                    Rectangle()
                        .fill(PaceColors.usage)
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

                    }
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(.primary.opacity(0.22), lineWidth: 0.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay {
                    Canvas { context, size in
                        let radius: CGFloat = 3.5
                        let centerY = size.height / 2
                        var marker = Path()
                        marker.move(to: CGPoint(x: markerX, y: centerY - radius))
                        marker.addLine(to: CGPoint(x: markerX + radius, y: centerY))
                        marker.addLine(to: CGPoint(x: markerX, y: centerY + radius))
                        marker.addLine(to: CGPoint(x: markerX - radius, y: centerY))
                        marker.closeSubpath()
                        context.fill(marker, with: .color(.black))
                        context.stroke(marker, with: .color(.white), lineWidth: 0.75)
                    }
                }
            }
        }
    }
}
