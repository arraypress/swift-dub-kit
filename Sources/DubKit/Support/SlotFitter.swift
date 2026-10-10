//
//  SlotFitter.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  The hard part of dubbing, as arithmetic. A translated line is almost
//  never the length of the original — Spanish ran 40% over English on the
//  first probe — so each line is given a slot: from where the original line
//  started to just before the next one starts, which lends it the pause
//  after it. A line that still does not fit is sped up, never past the cap;
//  what is left over is an overrun, pushes the next line back, and is
//  reported rather than hidden.
//
//  The speed cap is a judgement about listening, not a measurement of
//  understanding. MEASURED: Apple's recogniser still read Spanish, French
//  and German lines at 92–97% after a 1.6× speed-up and 90–97% at 1.8×
//  (Spanish fell to 81% at 2×) — but a recogniser is a better listener than
//  a person, and speech at 1.8× sounds hurried. 1.5× is the default.
//

import Foundation

/// Places dubbed lines on the timeline.
public enum SlotFitter {

    /// The fastest a line is spoken, as a multiple of its natural speed.
    public static let defaultMaximumSpeed = 1.5
    /// The silence kept between one dubbed line and the next, in seconds.
    public static let defaultGap: TimeInterval = 0.15

    /// Where each line goes and how fast it is spoken.
    ///
    /// - Parameters:
    ///   - lines: The original lines, in order.
    ///   - naturalDurations: How long each translation takes to say, unhurried.
    ///   - recordingDuration: The recording's length; the last slot ends there.
    ///   - maximumSpeed: The speed-up a line may not exceed.
    ///   - gap: The silence kept before the next line.
    /// - Returns: One placement per line.
    public static func place(_ lines: [DubLine], naturalDurations: [TimeInterval],
                             recordingDuration: TimeInterval,
                             maximumSpeed: Double = defaultMaximumSpeed,
                             gap: TimeInterval = defaultGap) -> [Placement] {
        var placements: [Placement] = []
        var previousEnd = -TimeInterval.infinity

        for (index, line) in lines.enumerated() {
            let natural = index < naturalDurations.count ? naturalDurations[index] : 0
            let slotEnd = index + 1 < lines.count ? lines[index + 1].start - gap : recordingDuration
            let start = max(line.start, previousEnd + gap)
            let available = max(0.01, slotEnd - start)

            let speed = natural <= available ? 1 : min(natural / available, max(1, maximumSpeed))
            let duration = natural / speed
            let placement = Placement(start: start, duration: duration, naturalDuration: natural,
                                      speed: speed, overrun: max(0, start + duration - slotEnd),
                                      delay: max(0, start - line.start))
            placements.append(placement)
            previousEnd = placement.end
        }
        return placements
    }
}
