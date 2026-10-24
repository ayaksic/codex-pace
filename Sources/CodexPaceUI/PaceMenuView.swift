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
    @State private var isShowingBankedResets = false
    @State private var isShowingWeeklyTimeline: Bool
    private let showsDisplaySizeControl: Bool
    private let popOutAction: (() -> Void)?
    private let maximumHeight: CGFloat
    private let scaleOverride: CGFloat?

    public init(
        model: PaceViewModel,
        isLargeDisplay: Binding<Bool>? = nil,
        showsWeeklyTimelineInitially: Bool = false,
        showsBankedResetsInitially: Bool = false,
        maximumHeight: CGFloat = .infinity,
        displayScale: CGFloat? = nil,
        popOutAction: (() -> Void)? = nil
    ) {
        self.model = model
        self._isLargeDisplay = isLargeDisplay ?? .constant(false)
        self._isShowingWeeklyTimeline = State(
            initialValue: showsWeeklyTimelineInitially
        )
        self._isShowingBankedResets = State(initialValue: showsBankedResetsInitially)
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
            scaledContent
        } else {
            BoundedContentLayout(maximumHeight: maximumHeight) {
                scaledContent.hidden().accessibilityHidden(true)
                ScrollView(.vertical) {
                    scaledContent
                }
            }
        }
    }

    private var scaledContent: some View {
        ScaledLayout(scale: displayScale) {
            VStack(spacing: PaceMenuLayout.sectionGap) {
                header

                if let snapshot = model.snapshot {
                    metrics(snapshot)
                    comparison(snapshot)
                    details(snapshot)
                } else {
                    unavailable
                }

                Divider()
                usageCredits

                if model.availableBankedResetCount > 0 {
                    Divider()
                    bankedResets
                }

                Divider()
                versionStatus
            }
            .font(PaceTypography.font(size: 13))
            .padding(.horizontal, PaceMenuLayout.horizontalPadding)
            .padding(.vertical, 16)
            .frame(width: PaceMenuLayout.width)
            .scaleEffect(displayScale, anchor: .topLeading)
        }
        .fixedSize(horizontal: false, vertical: true)
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
            if let countdown = model.nextRefreshCountdownFields {
                Text("Next update in \(DurationDisplay(fields: countdown).compactText)")
                    .font(PaceTypography.font(size: 11))
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
                        .font(PaceTypography.font(size: 12, weight: .medium))
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
                label: "Usage left",
                value: percent(weeklyWindow.usageRemainingPercent, places: 0)
            )
            Divider()
                .frame(height: 58)
                .padding(.horizontal, 8)
            MetricView(
                label: model.timeRemainingLabel,
                value: percent(weeklyWindow.timeRemainingPercent(at: model.now), places: 1)
            )
            Divider()
                .frame(height: 58)
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
                    WeeklyTimelineBar(progress: timelineProgress, label: model.timelineLabel)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 12) {
                        ComparisonBar(
                            label: "Usage",
                            value: weeklyWindow.usageRemainingPercent,
                            color: .accentColor
                        )
                        ComparisonBar(
                            label: model.resetCountdownTarget?.kind == .bankedResetExpiry ? "Expiry" : "Time",
                            value: weeklyWindow.timeRemainingPercent(at: model.now),
                            color: .purple
                        )
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    private func details(_ snapshot: PaceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: PaceMenuLayout.rowGap) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: PaceMenuLayout.rowGap) {
                if let paceTimeLabel = model.paceTimeLabel,
                   let paceTime = model.paceTimeFields {
                    GridRow {
                        detailLabel(paceTimeLabel, emphasized: true)
                        durationValue(paceTime, emphasized: true)
                        detailTimestamp(model.stoppageEndsAt)
                    }
                }
                if let projectedRunoutAt = model.projectedRunoutAt,
                   let countdown = model.projectedRunoutCountdownFields {
                    GridRow {
                        detailLabel("Projected runout", emphasized: true)
                        durationValue(countdown, emphasized: true)
                        detailTimestamp(projectedRunoutAt)
                    }
                }
                if let resetTarget = model.resetCountdownTarget {
                    GridRow {
                        detailLabel(resetLabel(for: resetTarget.kind))
                        durationValue(model.remainingTimeFields(until: resetTarget.date))
                        detailTimestamp(resetTarget.date)
                    }
                    if resetTarget.kind != .natural {
                        GridRow {
                            detailLabel("Weekly reset")
                            durationValue(model.remainingTimeFields(until: snapshot.weeklyWindow.resetsAt))
                            detailTimestamp(snapshot.weeklyWindow.resetsAt)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let error = model.errorMessage {
                Text(error)
                    .font(PaceTypography.font(size: 12))
                    .foregroundStyle(PaceColors.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var usageCredits: some View {
        // Peer rows share one parent-owned gap at both display scales.
        VStack(alignment: .leading, spacing: PaceMenuLayout.creditRowGap) {
            HStack {
                Text("Usage credits").font(PaceTypography.font(size: 13, weight: .medium))
                Spacer()
                Button(model.creditExpirationNote == nil ? "Add expiration" : "Edit expiration") {
                    isShowingCreditEditor = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .font(PaceTypography.font(size: 12))
                .accessibilityLabel("Edit usage credit expiration date")
            }
            HStack {
                Text(model.usageCreditReadingLabel).foregroundStyle(PaceColors.secondary)
                Spacer()
                if let dayText = model.creditExpirationDayText {
                    Text(dayText).monospacedDigit()
                        .help("Calendar days to the manually entered expiration date, using this Mac’s time zone")
                    Text("•").foregroundStyle(PaceColors.secondary)
                }
                Text(model.usageCreditBalanceText).monospacedDigit().textSelection(.enabled)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            if let note = model.creditExpirationNote {
                HStack {
                    HStack(spacing: 6) {
                        Text("Expiration").foregroundStyle(PaceColors.secondary)
                        metadataPill("Manual")
                    }
                    Spacer()
                    Text(note.isoDate).monospacedDigit()
                }
            }
        }
        .font(PaceTypography.font(size: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bankedResets: some View {
        VStack(spacing: PaceMenuLayout.rowGap) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    isShowingBankedResets.toggle()
                }
            } label: {
                HStack {
                    Text("Banked resets")
                        .font(PaceTypography.font(size: 13, weight: .medium))
                    Spacer()
                    metadataPill("\(model.availableBankedResetCount)")
                    Image(systemName: "chevron.right")
                        .font(PaceTypography.font(size: 12))
                        .foregroundStyle(PaceColors.secondary)
                        .rotationEffect(.degrees(isShowingBankedResets ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Banked resets, \(model.availableBankedResetCount)")
            .accessibilityValue(isShowingBankedResets ? "Expanded" : "Collapsed")

            if isShowingBankedResets {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: PaceMenuLayout.rowGap) {
                    ForEach(model.availableBankedResetCredits) { credit in
                        GridRow {
                            detailLabel("Expires")
                            if let expiresAt = credit.expiresAt {
                                durationValue(model.remainingTimeFields(until: expiresAt))
                                detailTimestamp(expiresAt)
                            } else {
                                Text("No expiration reported")
                                    .foregroundStyle(PaceColors.secondary)
                                    .gridCellColumns(2)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if model.bankedResetCountWithoutDetails > 0 {
                    Text(expirationDetailsUnavailableText)
                        .font(PaceTypography.font(size: 12))
                        .foregroundStyle(PaceColors.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .font(PaceTypography.font(size: 13))
    }

    private var unavailable: some View {
        VStack(spacing: 7) {
            if model.isRefreshing {
                Text("Reading Codex usage…")
                    .foregroundStyle(PaceColors.secondary)
            } else {
                Text("Usage unavailable")
                    .fontWeight(.medium)
                Text(model.errorMessage ?? "Refresh to try again.")
                    .font(PaceTypography.font(size: 12))
                    .foregroundStyle(PaceColors.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72)
    }

    private var versionStatus: some View {
        Button {
            isShowingBuildDetails.toggle()
        } label: {
            HStack(spacing: 8) {
                Text(model.appBuildInfo.version)
                Image(systemName: appUpdateStatusSymbol)
                    .foregroundStyle(appUpdateStatusColor)
                Text(model.appUpdateStatusText)
                    .foregroundStyle(appUpdateStatusColor)
                Spacer()
                Image(systemName: "info.circle")
            }
            .font(PaceTypography.font(size: 11))
            .foregroundStyle(PaceColors.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Build details and update check")
        .accessibilityLabel(
            "Codex Pace \(model.appBuildInfo.versionText), revision "
                + "\(model.appBuildInfo.shortRevision), \(model.appUpdateStatusText). Show build details."
        )
        .popover(isPresented: $isShowingBuildDetails) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Codex Pace \(model.appBuildInfo.version)")
                    .font(PaceTypography.font(size: 14, weight: .medium))
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
            .font(PaceTypography.font(size: 12))
            .padding(16)
        }
    }

    private func metadataPill(_ text: String) -> some View {
        Text(text)
            .font(PaceTypography.font(size: 11))
            .monospacedDigit()
            .foregroundStyle(PaceColors.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
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
            "Weekly reset"
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

    private func detailLabel(_ text: String, emphasized: Bool = false) -> some View {
        Text(text)
            .font(PaceTypography.font(size: 13, weight: emphasized ? .medium : .regular))
            .foregroundStyle(emphasized ? Color.primary : PaceColors.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
    }

    private func durationValue(_ fields: DurationFields, emphasized: Bool = false) -> some View {
        let display = DurationDisplay(fields: fields)
        return HStack(spacing: 4) {
            Text(display.days ?? "").frame(width: 35, alignment: .trailing)
            Text(display.hours ?? "").frame(width: 37, alignment: .trailing)
            Text(display.minutes ?? "").frame(width: 40, alignment: .trailing)
            Text(display.seconds).frame(width: 39, alignment: .trailing)
        }
        .font(PaceTypography.font(size: 18, weight: emphasized ? .bold : .medium))
        .monospacedDigit()
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(display.accessibilityLabel)
    }

    private func detailTimestamp(_ value: Date?) -> some View {
        Group {
            if let value {
                Text(value.formatted(.dateTime.month(.abbreviated).day(.twoDigits)
                    .locale(Locale(identifier: "en_US_POSIX"))))
                + Text(" · ")
                + Text(value.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))
                    .minute(.twoDigits).second(.twoDigits)
                    .locale(Locale(identifier: "en_US_POSIX"))))
            } else {
                Text("")
            }
        }
        .font(PaceTypography.font(size: 11))
        .foregroundStyle(PaceColors.secondary)
        .monospacedDigit()
        .frame(width: 158, alignment: .trailing)
        .lineLimit(1)
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
            Text("Expiration date (manual)").font(PaceTypography.font(size: 15, weight: .medium))
            TextField("Date (YYYY-MM-DD)", text: $dateText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Expiration date, YYYY-MM-DD")
            Text("A manually entered date for some usage credits. Codex reports their total balance here, without individual expiration dates.")
                .font(PaceTypography.font(size: 12)).foregroundStyle(PaceColors.secondary)
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
        .font(PaceTypography.font(size: 13))
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
                .font(PaceTypography.font(size: 15, weight: .medium))

            Text("Use this for a one-off reset expected before Codex's reported seven-day window ends.")
                .font(PaceTypography.font(size: 13))
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
                .font(PaceTypography.font(size: 13))
            }

            Text("Time left, bars and pace target the earliest of this estimate, a banked reset expiration, or the weekly reset. Percentages use a seven-day scale. Times use this Mac's time zone.")
                .font(PaceTypography.font(size: 12))
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
        .font(PaceTypography.font(size: 13))
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

private struct MetricView: View {
    let label: String
    let value: String
    var color: Color?

    var body: some View {
        VStack(spacing: 7) {
            Text(value)
                .font(PaceTypography.font(size: 34, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color ?? .primary)
            Text(label)
                .font(PaceTypography.font(size: 12, weight: color == nil ? .regular : .medium))
                .foregroundStyle(color ?? PaceColors.secondary)
                .padding(.horizontal, color == nil ? 0 : 8)
                .padding(.vertical, 2)
                .background {
                    if let color { Capsule().fill(color.opacity(0.12)) }
                }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ComparisonBar: View {
    private static let segmentCount = 100

    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Text(label)
                .font(PaceTypography.font(size: 12))
                .foregroundStyle(PaceColors.secondary)
                .frame(width: 49, alignment: .leading)
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
            .frame(height: 10)
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
    let label: String

    var body: some View {
        HStack(spacing: 7) {
            Text(label)
                .font(PaceTypography.font(size: 12))
                .foregroundStyle(PaceColors.secondary)
                .frame(width: 49, alignment: .leading)
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
