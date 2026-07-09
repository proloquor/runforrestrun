import SwiftUI
import UIKit

/// Live view of the raw BLE frames and decode steps from the direct Oura-ring
/// source. Use this to capture exactly what your ring sends so the IBI/BPM decoding
/// can be calibrated. Includes copy-to-clipboard for sharing a capture.
struct RingDebugView: View {
    @EnvironmentObject private var ringLogger: RingFrameLogger
    @EnvironmentObject private var monitor: HeartRateMonitor
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.cardStroke)
            if ringLogger.lines.isEmpty {
                emptyState
            } else {
                logList
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Ring debug log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        UIPasteboard.general.string = ringLogger.exportText
                        copied = true
                    } label: { Label("Copy log", systemImage: "doc.on.doc") }
                    Button(role: .destructive) {
                        ringLogger.clear()
                    } label: { Label("Clear", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if copied {
                Text("Copied to clipboard")
                    .font(.caption).bold()
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Theme.good, in: Capsule())
                    .padding(.bottom, 24)
                    .task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        copied = false
                    }
            }
        }
    }

    private var header: some View {
        HStack {
            Circle()
                .fill(monitor.isStreaming ? Theme.good : Color.orange)
                .frame(width: 8, height: 8)
            Text(monitor.sourceKind == .ouraRing ? "Direct ring source active" : "Select ‘Oura Ring (direct)’ to capture")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(ringLogger.lines.count) lines")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(12)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No frames yet")
                .font(.headline)
            Text("Switch the live source to “Oura Ring (direct)” with a saved key. Raw frames and decoded beats will stream in here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var logList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Array(ringLogger.lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(color(for: line))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding(12)
        }
    }

    private func color(for line: String) -> Color {
        if line.contains("← notify") { return Theme.accent }
        if line.contains("→ write") { return .secondary }
        if line.contains("bpm") { return Theme.good }
        if line.contains("❌") || line.contains("‼️") { return Theme.danger }
        if line.contains("✅") { return Theme.good }
        if line.contains("unknown") { return Theme.warning }
        return .primary
    }
}

#Preview {
    NavigationStack { RingDebugView() }.withPreviewEnvironment()
}
