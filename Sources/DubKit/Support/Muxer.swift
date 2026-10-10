//
//  Muxer.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  The original pictures with the new sound: every video track copied
//  across untouched, the original audio left behind, the dub put in its
//  place. Passthrough, so the picture is not re-encoded.
//

import AVFoundation
import Foundation

/// Puts a new soundtrack under a video.
public enum Muxer {

    /// Writes `video`'s pictures with `audio` as its only sound.
    ///
    /// - Parameters:
    ///   - video: The original.
    ///   - audio: The new soundtrack.
    ///   - output: Where to write; `.mov`, `.mp4` or `.m4v`.
    /// - Throws: ``DubError/exportFailed(_:)``.
    public static func replaceAudio(of video: URL, with audio: URL, to output: URL) async throws {
        let source = AVURLAsset(url: video), sound = AVURLAsset(url: audio)
        let composition = AVMutableComposition()
        do {
            let duration = try await source.load(.duration)
            for track in try await source.loadTracks(withMediaType: .video) {
                guard let copy = composition.addMutableTrack(withMediaType: .video,
                                                             preferredTrackID: kCMPersistentTrackID_Invalid) else { continue }
                try copy.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: .zero)
                copy.preferredTransform = try await track.load(.preferredTransform)
            }
            guard let soundTrack = try await sound.loadTracks(withMediaType: .audio).first,
                  let dub = composition.addMutableTrack(withMediaType: .audio,
                                                        preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw DubError.exportFailed("the new soundtrack has no audio")
            }
            let soundDuration = try await sound.load(.duration)
            try dub.insertTimeRange(CMTimeRange(start: .zero, duration: min(duration, soundDuration)),
                                    of: soundTrack, at: .zero)
        } catch let error as DubError {
            throw error
        } catch {
            throw DubError.exportFailed(error.localizedDescription)
        }

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw DubError.exportFailed("no export session for \(output.lastPathComponent)")
        }
        try? FileManager.default.removeItem(at: output)
        do {
            try await session.export(to: output, as: fileType(for: output))
        } catch {
            throw DubError.exportFailed(error.localizedDescription)
        }
    }

    static func fileType(for url: URL) -> AVFileType {
        switch url.pathExtension.lowercased() {
        case "mov": return .mov
        case "m4v": return .m4v
        default: return .mp4
        }
    }
}
