import Foundation
import AVFoundation

@MainActor
public final class SpeechAnnouncer {
    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenText: String = ""
    private var lastSpokenTime = Date.distantPast

    public init() {}

    public func announceIfNeeded(_ text: String, force: Bool = false) {
        let now = Date()
        guard force || text != lastSpokenText || now.timeIntervalSince(lastSpokenTime) > 4.0 else {
            return
        }

        lastSpokenText = text
        lastSpokenTime = now
        speak(text)
    }

    private func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        
        let voices = AVSpeechSynthesisVoice.speechVoices()
        if let premiumVoice = voices.first(where: { $0.language.starts(with: "en") && $0.quality == .premium }) {
            utterance.voice = premiumVoice
        } else if let enhancedVoice = voices.first(where: { $0.language.starts(with: "en") && $0.quality == .enhanced }) {
            utterance.voice = enhancedVoice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-GB") ?? AVSpeechSynthesisVoice(language: "en-US")
        }
        
        synthesizer.speak(utterance)
    }
}
