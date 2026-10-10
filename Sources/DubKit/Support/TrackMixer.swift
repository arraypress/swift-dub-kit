//
//  TrackMixer.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  The dubbed voice laid over what is left of the original: nothing, the
//  original turned right down (a voice-over), or the original with its
//  voice separated out (music and effects kept). The voice sits in the
//  centre; where the sum would clip, the whole mix is turned down rather
//  than the peaks squared off.
//

import Foundation

/// Mixes dubbed lines over a background.
public enum TrackMixer {

    /// One line of dubbed voice: mono samples at the mix rate, and where it starts.
    public struct Clip: Sendable, Equatable {
        public let samples: [Float]
        public let start: TimeInterval

        public init(samples: [Float], start: TimeInterval) {
            self.samples = samples
            self.start = start
        }
    }

    /// The finished stereo track.
    ///
    /// - Parameters:
    ///   - clips: The dubbed lines.
    ///   - background: Stereo background at the mix rate, or empty for none.
    ///   - backgroundGain: How loud the background is under the voice, 0–1.
    ///   - length: The track's length in frames — the recording's.
    ///   - sampleRate: The mix rate.
    /// - Returns: Left and right channels of `length` frames each, never
    ///   above full scale.
    public static func mix(_ clips: [Clip], background: [[Float]], backgroundGain: Float,
                           length: Int, sampleRate: Double) -> [[Float]] {
        var left = [Float](repeating: 0, count: length)
        var right = [Float](repeating: 0, count: length)
        if background.count == 2, backgroundGain > 0 {
            for index in 0..<min(length, background[0].count, background[1].count) {
                left[index] = background[0][index] * backgroundGain
                right[index] = background[1][index] * backgroundGain
            }
        }
        for clip in clips {
            let offset = Int((clip.start * sampleRate).rounded())
            for (index, sample) in clip.samples.enumerated() {
                let frame = offset + index
                guard frame >= 0, frame < length else { continue }
                left[frame] += sample
                right[frame] += sample
            }
        }
        // Scale the whole mix rather than clip the peaks.
        let peak = max(left.lazy.map(abs).max() ?? 0, right.lazy.map(abs).max() ?? 0)
        if peak > 0.99 {
            let scale = 0.99 / peak
            for index in 0..<length {
                left[index] *= scale
                right[index] *= scale
            }
        }
        return [left, right]
    }
}
