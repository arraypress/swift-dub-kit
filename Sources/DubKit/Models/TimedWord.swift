//
//  TimedWord.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  One recognised word and when it was said — the only thing the line
//  splitter needs from a recogniser, so any recogniser can feed it.
//

import Foundation

/// A word and its timing, in seconds from the start of the recording.
public struct TimedWord: Sendable, Codable, Equatable, Hashable {
    /// The word as recognised, with any punctuation the recogniser attached.
    public let text: String
    /// When it starts.
    public let start: TimeInterval
    /// When it ends.
    public let end: TimeInterval

    /// - Parameters:
    ///   - text: The word.
    ///   - start: When it starts, in seconds.
    ///   - end: When it ends, in seconds.
    public init(text: String, start: TimeInterval, end: TimeInterval) {
        self.text = text
        self.start = start
        self.end = end
    }
}
