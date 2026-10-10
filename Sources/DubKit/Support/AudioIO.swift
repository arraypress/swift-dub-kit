//
//  AudioIO.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  Sound in and out of files, as plain Float arrays: a recording's track
//  decoded to stereo at the mix rate, a voice resampled to it, and the
//  finished mix written as AAC or WAV. Everything in between is arithmetic
//  on arrays, which is what makes the mixer testable.
//

import AVFoundation
import Foundation

/// Reads, resamples and writes audio.
public enum AudioIO {

    /// The rate everything is mixed at.
    public static let mixRate: Double = 44_100

    /// A recording's sound as stereo samples at ``mixRate``.
    ///
    /// - Parameter url: Any file AVFoundation opens — a video's soundtrack
    ///   or an audio file.
    /// - Returns: Left and right channels, the same length.
    /// - Throws: ``DubError/noAudio(_:)`` or ``DubError/audioFailed(_:)``.
    public static func decode(_ url: URL) async throws -> [[Float]] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw DubError.noAudio(url.lastPathComponent)
        }
        let reader: AVAssetReader
        do { reader = try AVAssetReader(asset: asset) } catch { throw DubError.audioFailed(error.localizedDescription) }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false,
            AVSampleRateKey: mixRate, AVNumberOfChannelsKey: 2,
        ])
        reader.add(output)
        guard reader.startReading() else {
            throw DubError.audioFailed(reader.error?.localizedDescription ?? "the reader would not start")
        }
        var left: [Float] = [], right: [Float] = []
        while let buffer = output.copyNextSampleBuffer(), let block = CMSampleBufferGetDataBuffer(buffer) {
            var length = 0
            var pointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer)
            guard let pointer else { continue }
            let frames = length / (2 * MemoryLayout<Float>.size)
            pointer.withMemoryRebound(to: Float.self, capacity: frames * 2) { floats in
                for frame in 0..<frames {
                    left.append(floats[frame * 2])
                    right.append(floats[frame * 2 + 1])
                }
            }
        }
        guard reader.status == .completed else {
            throw DubError.audioFailed(reader.error?.localizedDescription ?? "decoding stopped early")
        }
        return [left, right]
    }

    /// Mono samples at another rate.
    ///
    /// - Parameters:
    ///   - samples: Mono audio.
    ///   - from: Its rate.
    ///   - to: The rate wanted.
    /// - Returns: The resampled audio.
    /// - Throws: ``DubError/audioFailed(_:)``.
    public static func resample(_ samples: [Float], from: Double, to: Double) throws -> [Float] {
        guard from != to, !samples.isEmpty else { return samples }
        guard let inFormat = AVAudioFormat(standardFormatWithSampleRate: from, channels: 1),
              let outFormat = AVAudioFormat(standardFormatWithSampleRate: to, channels: 1),
              let converter = AVAudioConverter(from: inFormat, to: outFormat),
              let input = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: AVAudioFrameCount(samples.count)),
              let output = AVAudioPCMBuffer(pcmFormat: outFormat,
                                            frameCapacity: AVAudioFrameCount(Double(samples.count) * to / from) + 1024) else {
            throw DubError.audioFailed("no converter from \(Int(from)) Hz to \(Int(to)) Hz")
        }
        input.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { input.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue
        var supplied = false
        var failure: NSError?
        converter.convert(to: output, error: &failure) { _, status in
            if supplied { status.pointee = .endOfStream; return nil }
            supplied = true
            status.pointee = .haveData
            return input
        }
        if let failure { throw DubError.audioFailed(failure.localizedDescription) }
        return Array(UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)))
    }

    /// Writes stereo samples at ``mixRate`` as AAC (`.m4a`) or WAV.
    ///
    /// - Parameters:
    ///   - channels: Left and right.
    ///   - url: Where to write; `.wav` writes WAV, anything else AAC.
    /// - Throws: ``DubError/audioFailed(_:)``.
    public static func write(_ channels: [[Float]], to url: URL) throws {
        let frames = channels.first?.count ?? 0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: mixRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(1, frames))) else {
            throw DubError.audioFailed("no buffer for \(frames) frames")
        }
        buffer.frameLength = AVAudioFrameCount(frames)
        for (index, channel) in channels.prefix(2).enumerated() {
            channel.withUnsafeBufferPointer { buffer.floatChannelData![index].update(from: $0.baseAddress!, count: frames) }
        }
        let settings: [String: Any] = url.pathExtension.lowercased() == "wav"
            ? format.settings
            : [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: mixRate, AVNumberOfChannelsKey: 2,
               AVEncoderBitRateKey: 192_000]
        try? FileManager.default.removeItem(at: url)
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings)
            try file.write(from: buffer)
        } catch {
            throw DubError.audioFailed(error.localizedDescription)
        }
    }
}
