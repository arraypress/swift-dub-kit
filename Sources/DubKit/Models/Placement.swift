//
//  Placement.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  Where one dubbed line goes and how fast it is spoken — the answer to the
//  hard part of dubbing, which is that a translation is almost never the
//  length of what it translates. Spanish ran 40% longer than the English it
//  came from on the first probe.
//

import Foundation

/// Where a dubbed line lands on the timeline.
public struct Placement: Sendable, Codable, Equatable, Hashable {
    /// When the dubbed line starts, in seconds.
    public let start: TimeInterval
    /// How long it lasts once fitted.
    public let duration: TimeInterval
    /// How long it lasted as synthesised, before fitting.
    public let naturalDuration: TimeInterval
    /// How much it was sped up: 1 is untouched.
    public let speed: Double
    /// How far it runs past the start of the next line's slot, in seconds,
    /// even at the fastest allowed speed — and so how far it pushes that
    /// line back. Zero when it fits.
    public let overrun: TimeInterval
    /// How far its start was pushed past the original line's start by the
    /// line before it overrunning.
    public let delay: TimeInterval

    /// - Parameters:
    ///   - start: When it starts.
    ///   - duration: Its fitted length.
    ///   - naturalDuration: Its synthesised length.
    ///   - speed: The speed-up applied.
    ///   - overrun: How far it runs into the next line's slot.
    ///   - delay: How far it was pushed late.
    public init(start: TimeInterval, duration: TimeInterval, naturalDuration: TimeInterval,
                speed: Double, overrun: TimeInterval, delay: TimeInterval) {
        self.start = start
        self.duration = duration
        self.naturalDuration = naturalDuration
        self.speed = speed
        self.overrun = overrun
        self.delay = delay
    }

    /// When it ends.
    public var end: TimeInterval { start + duration }

    /// Whether it fits its slot without disturbing the line after it.
    public var fits: Bool { overrun < 0.001 }
}
