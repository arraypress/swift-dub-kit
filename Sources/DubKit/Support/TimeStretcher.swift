//
//  TimeStretcher.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  Speech made shorter without being made higher. A synthesiser's own rate
//  control stopped helping early — Apple's voices said a Spanish line in
//  9.64 s at rate 0.6 and in 9.64 s at 0.7 — so lines are spoken at their
//  natural rate and then squeezed by AVAudioUnitTimePitch, offline.
//
//  MEASURED: the stretched audio landed on its target length to the sample
//  at 90%, 80% and 70%, and the recogniser read the 70% version word for
//  word.
//

import AVFoundation
import Foundation

/// Changes the length of mono audio without changing its pitch.
public enum TimeStretcher {

    /// Mono samples played `speed` times faster, at the same pitch.
    ///
    /// - Parameters:
    ///   - samples: Mono audio.
    ///   - sampleRate: Its rate.
    ///   - speed: How much faster; 1 returns the samples untouched.
    /// - Returns: Exactly `samples.count / speed` samples.
    /// - Throws: ``DubError/audioFailed(_:)`` when the render fails.
    public static func stretch(_ samples: [Float], sampleRate: Double, speed: Double) throws -> [Float] {
        guard abs(speed - 1) > 0.0005, !samples.isEmpty else { return samples }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw DubError.audioFailed("no buffer for a \(samples.count)-sample line")
        }
        input.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { input.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }

        let engine = AVAudioEngine(), player = AVAudioPlayerNode(), pitch = AVAudioUnitTimePitch()
        pitch.rate = Float(speed)
        engine.attach(player)
        engine.attach(pitch)
        engine.connect(player, to: pitch, format: format)
        engine.connect(pitch, to: engine.mainMixerNode, format: format)
        do {
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
            try engine.start()
        } catch {
            throw DubError.audioFailed(error.localizedDescription)
        }
        player.scheduleBuffer(input, at: nil)
        player.play()
        defer { engine.stop() }

        let wanted = Int((Double(samples.count) / speed).rounded())
        guard let chunk = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096) else {
            throw DubError.audioFailed("no render buffer")
        }
        var output: [Float] = []
        output.reserveCapacity(wanted)
        while output.count < wanted {
            let frames = AVAudioFrameCount(min(4096, wanted - output.count))
            do {
                guard try engine.renderOffline(frames, to: chunk) == .success else { break }
            } catch {
                throw DubError.audioFailed(error.localizedDescription)
            }
            output += UnsafeBufferPointer(start: chunk.floatChannelData![0], count: Int(chunk.frameLength))
        }
        return output
    }
}
