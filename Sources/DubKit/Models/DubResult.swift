//
//  DubResult.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  What a dub came to, line by line: where each line went, how fast it was
//  said, and which ones did not fit — the numbers that say whether to trust
//  it before anyone listens.
//

import Foundation

/// A finished dub and how well it fits.
public struct DubResult: Sendable {
    /// The plan that was voiced.
    public let plan: DubPlan
    /// Where each line went, in the plan's order.
    public let placements: [Placement]
    /// The file written.
    public let output: URL
    /// Whether the original had no pictures.
    public let audioOnly: Bool

    /// - Parameters:
    ///   - plan: The plan voiced.
    ///   - placements: One per line.
    ///   - output: The file written.
    ///   - audioOnly: Whether there were no pictures.
    public init(plan: DubPlan, placements: [Placement], output: URL, audioOnly: Bool) {
        self.plan = plan
        self.placements = placements
        self.output = output
        self.audioOnly = audioOnly
    }

    /// Lines that had to be sped up to fit.
    public var spedUp: Int { placements.filter { $0.speed > 1.001 }.count }
    /// Lines that ran into the next line's slot even at the fastest speed.
    public var overrunning: Int { placements.filter { !$0.fits }.count }
    /// The fastest any line was spoken.
    public var fastest: Double { placements.map(\.speed).max() ?? 1 }
    /// The latest any line started, against its original, in seconds.
    public var latest: TimeInterval { placements.map(\.delay).max() ?? 0 }
    /// The furthest any line ran past its slot, in seconds. On the last line
    /// of a video this much is cut off with the picture.
    public var worstOverrun: TimeInterval { placements.map(\.overrun).max() ?? 0 }
}
