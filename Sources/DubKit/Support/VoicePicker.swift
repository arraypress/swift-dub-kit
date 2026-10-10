//
//  VoicePicker.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  Which voice says a dub when the caller names none. The first voice an
//  engine lists is not the one to want: Apple's list carries the smallest
//  voices (super-compact) and Eloquence's novelty cast (Grandma, Rocko)
//  beside any enhanced or premium voice the user downloaded, in no order
//  that ranks them. An engine with no voice in the language at all — Kokoro,
//  whose pipeline here is English-only — is refused, because handed Spanish
//  text its English voice crashed the model rather than failing cleanly.
//

import Foundation
import SpeechSynthesizer

/// Chooses the default voice for a language.
public enum VoicePicker {

    /// The voices an engine has for a language, best first.
    ///
    /// Premium beats enhanced beats compact; Eloquence's voices come last.
    /// Among equals the engine's own order stands.
    ///
    /// - Parameters:
    ///   - voices: What the engine offers.
    ///   - language: A language code, `es` or `es-MX`.
    /// - Returns: The voices that speak it, empty when none does.
    public static func ranked(_ voices: [TTSVoice], for language: String) -> [TTSVoice] {
        let wanted = language.lowercased()
        return voices.enumerated()
            .filter { $0.element.language.lowercased().hasPrefix(wanted) }
            .sorted { ($0.element.tier, $0.offset) < ($1.element.tier, $1.offset) }
            .map(\.element)
    }

    /// The best voice an engine has for a language, or nil when it has none.
    public static func best(of voices: [TTSVoice], for language: String) -> TTSVoice? {
        ranked(voices, for: language).first
    }

    /// A voice's rank, best first (premium is 0), read from Apple's identifiers;
    /// another engine's voices all share the middle tier.
    static func tier(of id: String) -> Int {
        let id = id.lowercased()
        if id.contains(".premium.") { return 0 }
        if id.contains(".enhanced.") { return 1 }
        if id.contains(".super-compact.") { return 3 }
        if id.contains(".eloquence.") { return 4 }
        return 2
    }
}
