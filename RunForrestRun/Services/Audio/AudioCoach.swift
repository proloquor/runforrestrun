import Foundation
import AVFoundation
import UIKit

/// Produces the audible + haptic coaching cues. Three layers:
///  1. Spoken guidance ("Ease off, heart rate too high") via AVSpeechSynthesizer —
///     clear through headphones mid-run.
///  2. A short tone (higher pitch = too high, lower pitch = too low) generated in
///     code so there are no audio assets to ship.
///  3. Haptic feedback for when you can't hear anything.
///
/// The audio session is configured to duck (not stop) your music/podcast.
@MainActor
final class AudioCoach: ObservableObject {
    enum Cue {
        case above          // HR over the target band
        case below          // HR under the target band
        case backInZone
        case phase(String)  // spoken phase announcement
    }

    @Published var isMuted: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var tonePlayer: AVAudioPlayer?
    private let notificationHaptics = UINotificationFeedbackGenerator()

    func activateSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .mixWithOthers, .interruptSpokenAudioAndMixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal: cues just won't duck music.
        }
    }

    func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func play(_ cue: Cue) {
        guard !isMuted else { return }
        switch cue {
        case .above:
            playTone(frequency: 990, duration: 0.18, pulses: 2)
            notificationHaptics.notificationOccurred(.warning)
            speak("Ease off. Heart rate too high.")
        case .below:
            playTone(frequency: 520, duration: 0.22, pulses: 2)
            notificationHaptics.notificationOccurred(.warning)
            speak("Pick it up. Heart rate too low.")
        case .backInZone:
            playTone(frequency: 740, duration: 0.14, pulses: 1)
            notificationHaptics.notificationOccurred(.success)
            speak("Back in the zone.")
        case .phase(let text):
            notificationHaptics.notificationOccurred(.success)
            speak(text)
        }
    }

    func speak(_ text: String) {
        guard !isMuted else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    // MARK: - Tone synthesis

    private func playTone(frequency: Double, duration: Double, pulses: Int) {
        guard let data = Self.makeToneWAV(frequency: frequency, duration: duration, pulses: pulses) else { return }
        do {
            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            player.play()
            tonePlayer = player
        } catch {
            // Ignore — the spoken cue still plays.
        }
    }

    /// Builds a little PCM WAV (16-bit mono) with `pulses` sine bursts separated by
    /// short gaps. Returned as in-memory Data so AVAudioPlayer can play it.
    static func makeToneWAV(frequency: Double, duration: Double, pulses: Int) -> Data? {
        let sampleRate = 44_100.0
        let gap = 0.06
        var samples: [Int16] = []

        for pulse in 0..<max(pulses, 1) {
            let count = Int(duration * sampleRate)
            for i in 0..<count {
                let t = Double(i) / sampleRate
                // Simple attack/decay envelope to avoid clicks.
                let env = min(1.0, min(t / 0.01, (duration - t) / 0.02))
                let value = sin(2.0 * Double.pi * frequency * t) * env * 0.6
                samples.append(Int16(value * Double(Int16.max)))
            }
            if pulse < pulses - 1 {
                samples.append(contentsOf: [Int16](repeating: 0, count: Int(gap * sampleRate)))
            }
        }
        return wavData(from: samples, sampleRate: Int(sampleRate))
    }

    private static func wavData(from samples: [Int16], sampleRate: Int) -> Data {
        var data = Data()
        let byteRate = sampleRate * 2
        let dataSize = samples.count * 2

        func appendString(_ s: String) { data.append(contentsOf: s.utf8) }
        func appendUInt32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        func appendUInt16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }

        appendString("RIFF")
        appendUInt32(UInt32(36 + dataSize))
        appendString("WAVE")
        appendString("fmt ")
        appendUInt32(16)               // PCM chunk size
        appendUInt16(1)                // PCM format
        appendUInt16(1)                // mono
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(byteRate))
        appendUInt16(2)                // block align
        appendUInt16(16)               // bits per sample
        appendString("data")
        appendUInt32(UInt32(dataSize))
        for sample in samples {
            var x = sample.littleEndian
            withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
        }
        return data
    }
}
