//
//  DubPlan.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  Everything decided before a voice is synthesised: the lines, the
//  languages, and which translator did the work. The file an agent edits
//  between hearing a video and dubbing it.
//

import Foundation

/// The lines of a dub and the languages between them.
public struct DubPlan: Sendable, Codable, Equatable {
    /// The language spoken in the original, as a code.
    public var from: String
    /// The language of the dub, as a code.
    public var to: String
    /// Which translator produced the translations — "apple" stayed on this
    /// machine, "google" did not — or "edited" once a person has changed them.
    public var translator: String
    /// The original recording's length, in seconds.
    public var duration: TimeInterval
    /// The lines, in order.
    public var lines: [DubLine]

    /// - Parameters:
    ///   - from: The original language.
    ///   - to: The dub's language.
    ///   - translator: Who translated it.
    ///   - duration: The recording's length.
    ///   - lines: The lines.
    public init(from: String, to: String, translator: String, duration: TimeInterval, lines: [DubLine]) {
        self.from = from
        self.to = to
        self.translator = translator
        self.duration = duration
        self.lines = lines
    }
}
