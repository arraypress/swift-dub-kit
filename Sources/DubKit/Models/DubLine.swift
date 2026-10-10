//
//  DubLine.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  One line of a dub: what was said and when, and what it becomes. Codable
//  so a plan can be written out, corrected by a person or an agent — a name
//  the translator mangled, a phrase that reads stiffly — and read back in
//  without hearing or translating anything again.
//

import Foundation

/// A line of speech and its translation.
public struct DubLine: Sendable, Codable, Equatable, Hashable {
    /// When the original line starts, in seconds.
    public var start: TimeInterval
    /// When it ends.
    public var end: TimeInterval
    /// What was said.
    public var source: String
    /// What it becomes. Empty until translated.
    public var translation: String

    /// - Parameters:
    ///   - start: When the line starts.
    ///   - end: When it ends.
    ///   - source: What was said.
    ///   - translation: What it becomes.
    public init(start: TimeInterval, end: TimeInterval, source: String, translation: String = "") {
        self.start = start
        self.end = end
        self.source = source
        self.translation = translation
    }

    /// How long the original line lasts.
    public var duration: TimeInterval { end - start }
}
