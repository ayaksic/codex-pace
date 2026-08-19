import AppKit
import CodexPaceCore
import SwiftUI

public struct PaceMenuView: View {
    @ObservedObject var model: PaceViewModel

    public init(model: PaceViewModel) {
        self.model = model
    }

    public var body: some View {
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
        .frame(width: 292)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .foregroundStyle(.tint)
            Text("Codex Pace")
                .font(.headline)
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
        }
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
                color: .secondary
            )
        }
    }

    private func details(_ snapshot: PaceSnapshot) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("Pace")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(model.paceText)
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor(snapshot.paceState(at: model.now)))
            }
            HStack {
                Text("Resets")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(snapshot.weeklyWindow.resetsAt.formatted(
                    .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()
                ))
                .monospacedDigit()
            }
            HStack {
                Text(model.errorMessage == nil ? "Updated" : "Last good reading")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(snapshot.fetchedAt.formatted(.relative(presentation: .named)))
            }
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

    private func statusColor(_ state: PaceState) -> Color {
        switch state {
        case .ahead, .onPace:
            .green
        case .behind:
            .orange
        }
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
                }
            }
            .frame(height: 5)
        }
    }
}
