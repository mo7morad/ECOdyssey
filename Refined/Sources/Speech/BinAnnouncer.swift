import AVFoundation

/// Speaks the bin instruction aloud.
public actor BinAnnouncer {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?

    /// - Parameter localeIdentifier: comes from the ruleset, because the bin names being
    ///   read out are ruleset data too. An Indonesian ruleset read in a US English voice
    ///   pronounces "Anorganik" as nothing anyone would recognise.
    public init(localeIdentifier: String) {
        self.voice = AVSpeechSynthesisVoice(language: localeIdentifier)
    }

    public func announce(_ phrase: String) {
        // The newest item is the one the person is holding, so it interrupts rather
        // than queues. Letting utterances stack would leave someone listening to the
        // instruction for the item before theirs.
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: phrase)
        // Left nil when the device has no voice installed for the locale: the system
        // falls back to its default rather than staying silent.
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        synthesizer.speak(utterance)
    }
}
