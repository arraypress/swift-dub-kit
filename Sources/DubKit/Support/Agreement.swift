//
//  Agreement.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  The second listen, scored. A dub is checked by recognising it again and
//  comparing what was heard with what was meant to be said — word by word,
//  through TextDiff, so one misheard word costs one word and not every word
//  after it.
//

import Foundation
import TextDiff

/// Scores what was heard against what was meant.
public enum Agreement {

    /// The share of the intended words heard again, in order, from 0 to 1.
    ///
    /// Case, accents and punctuation are set aside first: a recogniser that
    /// writes "rapido" for "rápido" heard the word.
    ///
    /// - Parameters:
    ///   - intended: What the dub was meant to say.
    ///   - heard: What a second recognition found.
    /// - Returns: 1 when nothing was intended.
    public static func score(intended: String, heard: String) -> Double {
        let old = normalised(intended), new = normalised(heard)
        guard !old.isEmpty else { return 1 }
        guard !new.isEmpty else { return 0 }
        // One word per line, diffed as lines: TextDiff's word mode counts
        // the spaces between words as tokens too, which scored "uno dos
        // tres cuatro" against "… cinco" as 6 of 7 rather than 3 of 4.
        let stats = TextDiff.stats(old, new)
        return stats.oldCount == 0 ? 1 : Double(stats.unchanged) / Double(stats.oldCount)
    }

    /// Lowercased, unaccented, one word per line.
    static func normalised(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
