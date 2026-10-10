//
//  SpeechLocale.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  A language code as the recogniser wants it. The translator takes "es";
//  the recogniser's models are installed per region, and a bare code may
//  name none of them, so the commonest region is filled in.
//

import Foundation

/// Language codes to recogniser locales.
public enum SpeechLocale {

    /// The region assumed for a bare language code.
    static let regions: [String: String] = [
        "en": "en-US", "es": "es-ES", "fr": "fr-FR", "de": "de-DE", "it": "it-IT",
        "pt": "pt-BR", "ja": "ja-JP", "zh": "zh-CN", "ko": "ko-KR", "nl": "nl-NL",
        "sv": "sv-SE", "da": "da-DK", "nb": "nb-NO", "fi": "fi-FI", "pl": "pl-PL",
        "ru": "ru-RU", "tr": "tr-TR", "ar": "ar-SA", "hi": "hi-IN", "uk": "uk-UA",
    ]

    /// The locale to recognise a language in.
    ///
    /// - Parameter code: `es`, `es-MX`, `pt_BR` — a region given is kept.
    /// - Returns: A locale with a region.
    public static func locale(for code: String) -> Locale {
        let normalised = code.replacingOccurrences(of: "_", with: "-")
        if normalised.contains("-") { return Locale(identifier: normalised) }
        return Locale(identifier: regions[normalised.lowercased()] ?? normalised)
    }
}
