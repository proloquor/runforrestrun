import SwiftUI

/// Big circular heart-rate readout that turns red/amber/green with zone status.
struct HeartRateGauge: View {
    let bpm: Int?
    let fractionOfMax: Double
    let status: WorkoutEngine.ZoneStatus
    let targetRange: ClosedRange<Int>?

    private var ringColor: Color {
        switch status {
        case .inZone: return Theme.good
        case .above: return Theme.danger
        case .below: return Theme.warning
        case .noSignal: return .gray
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 16)

            Circle()
                .trim(from: 0, to: min(max(fractionOfMax, 0), 1))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: fractionOfMax)

            VStack(spacing: 2) {
                if let bpm {
                    Text("\(bpm)")
                        .font(.system(size: 68, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("BPM")
                        .font(.caption).bold()
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("No signal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let targetRange {
                    Text("Target \(targetRange.lowerBound)–\(targetRange.upperBound)")
                        .font(.caption2)
                        .foregroundStyle(ringColor)
                        .padding(.top, 4)
                }
            }
        }
        .frame(width: 240, height: 240)
    }
}

/// A cue banner that tells you which way to adjust.
struct ZoneStatusBanner: View {
    let status: WorkoutEngine.ZoneStatus
    let enforced: Bool

    var body: some View {
        if enforced, status != .noSignal {
            HStack(spacing: 10) {
                Image(systemName: icon)
                Text(text)
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var icon: String {
        switch status {
        case .above: return "arrow.down.circle.fill"
        case .below: return "arrow.up.circle.fill"
        case .inZone: return "checkmark.circle.fill"
        case .noSignal: return "questionmark"
        }
    }
    private var text: String {
        switch status {
        case .above: return "Ease off — too high"
        case .below: return "Push harder — too low"
        case .inZone: return "In the zone"
        case .noSignal: return ""
        }
    }
    private var color: Color {
        switch status {
        case .above: return Theme.danger
        case .below: return Theme.warning
        case .inZone: return Theme.good
        case .noSignal: return .gray
        }
    }
}

/// Horizontal strip of the five zones with the current BPM marker.
struct ZoneStrip: View {
    let profile: UserProfile
    let currentBPM: Int?

    var body: some View {
        let ranges = ZoneCalculator.allZoneRanges(profile: profile)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                ForEach(ranges, id: \.zone) { item in
                    let isCurrent = currentBPM.map { item.range.contains($0) } ?? false
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.zone.color.opacity(isCurrent ? 1 : 0.35))
                            .frame(height: isCurrent ? 26 : 18)
                        Text("Z\(item.zone.rawValue)")
                            .font(.caption2)
                            .foregroundStyle(isCurrent ? .primary : .secondary)
                    }
                }
            }
            if let bpm = currentBPM, let zone = ZoneCalculator.zone(forBPM: bpm, profile: profile) {
                Text("\(zone.name) · \(zone.label)")
                    .font(.caption)
                    .foregroundStyle(zone.color)
            }
        }
    }
}

/// A pill showing the live heart-rate source connection state.
struct SourceStatusPill: View {
    @EnvironmentObject private var monitor: HeartRateMonitor

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(monitor.isStreaming ? Theme.good : Color.orange)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        switch monitor.connectionState {
        case .connected(let name): return name ?? monitor.sourceKind.displayName
        case .connecting: return "Connecting…"
        case .disconnected: return "Not connected"
        case .unavailable(let reason): return reason
        }
    }
}
