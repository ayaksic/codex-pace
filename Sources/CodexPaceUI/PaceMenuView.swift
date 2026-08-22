import AppKit
import CodexPaceCore
import SwiftUI

public struct PaceMenuView: View {
    @ObservedObject var model: PaceViewModel
    @Binding private var isLargeDisplay: Bool
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

                Divider()
                footer
            }
            .padding(12)
            .frame(width: 412)
            .scaleEffect(displayScale, anchor: .topLeading)
        }
    }

    private var header: some View {
        ZStack {
            Text(model.paceText)
                .font(.headline)
                .foregroundStyle(headerColor)

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
        }
        .frame(maxWidth: .infinity)
    }

    private func metrics(_ snapshot: PaceSnapshot) -> some View {
        HStack(spacing: 0) {
            MetricView(
                label: "Usage left",
                value: percent(snapshot.weeklyWindow.usageRemainingPercent, places: 0)
            )
            Divider()
                .frame(height: 35)
                .padding(.horizontal, 12)
            MetricView(
                label: "Week left",
                value: percent(snapshot.weeklyWindow.timeRemainingPercent(at: model.now), places: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func comparison(_ snapshot: PaceSnapshot) -> some View {
        VStack(spacing: 6) {
            ComparisonBar(
                label: "Usage",
                value: snapshot.weeklyWindow.usageRemainingPercent,
                color: .accentColor
            )
            ComparisonBar(
                label: "Time",
                value: snapshot.weeklyWindow.timeRemainingPercent(at: model.now),
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
                GridRow {
                    detailLabel("Resets")
                    durationValue(
                        model.remainingTimeFields(until: snapshot.weeklyWindow.resetsAt)
                    )
                    timestampSeparator
                    timestampDate(snapshot.weeklyWindow.resetsAt)
                    timestampTime(snapshot.weeklyWindow.resetsAt)
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

    private var footer: some View {
        HStack {
            Text("usage / time remaining")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
    }

    private func percent(_ value: Double, places: Int) -> String {
        value.formatted(.number.precision(.fractionLength(places))) + "%"
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
            Text(fields.hours == 0 ? "" : "\(fields.hours)h")
                .frame(width: 38, alignment: .trailing)
            Text(hidesZeroMinutes && fields.minutes == 0 ? "" : "\(fields.minutes)m")
                .frame(width: 30, alignment: .trailing)
            Text("\(fields.seconds)s")
                .frame(width: 30, alignment: .trailing)
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
        let hourText = fields.hours == 0 ? nil : "\(fields.hours) hours"
        let minuteText = hidesZeroMinutes && fields.minutes == 0
            ? nil
            : "\(fields.minutes) minutes"
        return [hourText, minuteText, "\(fields.seconds) seconds"]
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
        guard let snapshot = model.snapshot else { return .secondary }
        return statusColor(snapshot.paceState(at: model.now))
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

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
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
