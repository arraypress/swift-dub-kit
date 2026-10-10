//
//  Background.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  What plays under the dubbed voice. A professional dub keeps the music
//  and the room and replaces only the speaker; that takes a separation
//  model, which this library does not carry — a caller with one (`stems`
//  has MDX-Net) hands the instrumental in as samples.
//

import Foundation

/// What sits under the dubbed voice.
public enum Background: Sendable {
    /// Nothing: the dubbed voice alone.
    case none
    /// The original soundtrack, turned down — a voice-over, the original
    /// speaker faintly audible beneath. The gain is linear, 0–1.
    case original(gain: Float)
    /// A soundtrack the caller prepared — the original with its voice
    /// separated out — as stereo samples at ``AudioIO/mixRate``.
    case samples([[Float]], gain: Float)

    /// A voice-over at -18 dB: the original audible, not competing.
    public static let voiceOver = Background.original(gain: 0.125)
}
