//
//  LineSplitter.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  Words into lines a translator can translate and a voice can say. A line
//  ends where the speaker stops: at a pause, or at sentence punctuation when
//  the recogniser supplies any (Whisper does; Apple's words come back bare).
//  A line that runs on is broken at its widest gap, so a long sentence is
//  split where the speaker breathed rather than mid-phrase.
//

import Foundation

/// Groups recognised words into dubbing lines.
public enum LineSplitter {

    /// A gap this long between two words ends a line.
    public static let defaultPause: TimeInterval = 0.45
    /// A line longer than this is broken at its widest internal gap. Long
    /// lines translate better than fragments, but a twelve-second slot that
    /// comes out three seconds over is harder to fit than two short ones.
    public static let defaultLongest: TimeInterval = 12

    /// The lines in a stream of words.
    ///
    /// - Parameters:
    ///   - words: The recognised words, in order.
    ///   - pause: The gap that ends a line.
    ///   - longest: The length past which a line is broken.
    /// - Returns: The lines, untranslated, in order.
    public static func lines(from words: [TimedWord], pause: TimeInterval = defaultPause,
                             longest: TimeInterval = defaultLongest) -> [DubLine] {
        var lines: [DubLine] = []
        var current: [TimedWord] = []

        func close(_ group: [TimedWord]) {
            guard let first = group.first, let last = group.last else { return }
            lines.append(DubLine(start: first.start, end: last.end,
                                 source: group.map(\.text).joined(separator: " ")))
        }

        for word in words {
            if let last = current.last {
                let gap = word.start - last.end
                if gap >= pause || endsSentence(last.text) {
                    close(current)
                    current = []
                } else if word.end - current[0].start > longest, current.count > 1 {
                    // Break at the widest gap so far, keeping the rest going.
                    let split = widestGap(in: current)
                    close(Array(current[..<split]))
                    current = Array(current[split...])
                }
            }
            current.append(word)
        }
        close(current)
        return lines
    }

    /// Whether a word ends a sentence by its punctuation.
    static func endsSentence(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespaces).last else { return false }
        return ".!?…。！？".contains(last)
    }

    /// The index of the word after the widest gap in a run of words.
    static func widestGap(in words: [TimedWord]) -> Int {
        var best = 1, widest = -TimeInterval.infinity
        for index in 1..<words.count {
            let gap = words[index].start - words[index - 1].end
            if gap > widest { widest = gap; best = index }
        }
        return best
    }
}
