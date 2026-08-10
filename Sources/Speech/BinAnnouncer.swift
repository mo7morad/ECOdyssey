import AVFoundation

/// Speaks the bin instruction aloud.
public actor BinAnnouncer {
    private let synthesizer = AVSpeechSynthesizer()

    public init() {}

    public func announce(_ phrase: String) {
        // The newest item is the one the person is holding, so it interrupts rather
        // than queues. Letting utterances stack would leave someone listening to the
        // instruction for the item before theirs.
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: phrase)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        synthesizer.speak(utterance)
    }
}
