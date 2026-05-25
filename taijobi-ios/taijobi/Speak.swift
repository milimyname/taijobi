import AVFoundation

/// Tiny AVSpeechSynthesizer wrapper that mirrors taijobi-web/src/lib/speak.ts.
/// Maps a language code (zh/de/en/ar) to a BCP-47 locale, falls back to the
/// `detect()` heuristic when the caller passes "auto".
///
/// Held as a singleton so the synthesizer lives across taps — instantiating
/// one per tap leaks an utterance queue and sometimes drops the first call.
enum Speak {
    /// Single shared synthesizer — AVSpeechSynthesizer holds an underlying
    /// audio session and shouldn't be re-instantiated per tap.
    static let shared = AVSpeechSynthesizer()

    private static let langMap: [String: String] = [
        "zh": "zh-CN",
        "de": "de-DE",
        "en": "en-US",
        "ar": "ar-SA",
        "ja": "ja-JP",
        "ko": "ko-KR",
        "fr": "fr-FR",
        "es": "es-ES",
        "ru": "ru-RU",
    ]

    /// Language detection lives in libtaijobi (`lang.zig`) — one source
    /// of truth shared with TS + the lexicon insert path. The tiny
    /// fallback only runs when the library isn't initialised yet (no
    /// realistic code path hits it, but keeps `detect` total).
    static func detect(_ text: String) -> String {
        if let z = LibTaijobi.shared.detectLanguage(text) { return z }
        if text.range(of: #"\p{Han}"#, options: .regularExpression) != nil { return "zh" }
        if text.range(of: #"\p{Arabic}"#, options: .regularExpression) != nil { return "ar" }
        if text.range(of: "[äöüÄÖÜß]", options: .regularExpression) != nil { return "de" }
        return "en"
    }

    /// Speak the given text. Pass `"auto"` (or omit) to use the heuristic.
    static func say(_ text: String, language: String = "auto") {
        guard !text.isEmpty else { return }
        let lang = language == "auto" ? detect(text) : language
        let bcp = langMap[lang] ?? "en-US"

        // Stop the previous utterance — the user tapping a new word means
        // they're done listening to the old one.
        if shared.isSpeaking {
            shared.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: bcp)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        shared.speak(utterance)
    }

    static var canSpeak: Bool { true }
}
