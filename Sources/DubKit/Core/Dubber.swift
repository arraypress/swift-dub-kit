//
//  Dubber.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  The front door. A dub is four steps, each reachable on its own so a
//  caller can stop between them: hear the original (`listen`), turn it into
//  lines and translate them (`plan`), say them and fit them to the picture
//  (`render`), and hear the result again (`verify`). The plan in the middle
//  is plain data — write it out, fix a name the translator mangled, read it
//  back — so the expensive first half never has to run twice.
//

import AVFoundation
import Foundation
import SpeechSynthesizer
import SpeechTranscriber
import Translate

/// Dubs a recording into another language, on this machine.
///
/// ```swift
/// let plan = try await Dubber.plan(for: talk, from: "en", to: "es")
/// let result = try await Dubber.render(plan, source: talk, to: dubbed,
///                                      engine: AppleEngine(), background: .voiceOver)
/// result.overrunning   // 0 — every line fitted its slot
/// ```
public enum Dubber {

    // MARK: - Hearing

    /// The words in a recording and when they were said.
    ///
    /// - Parameters:
    ///   - url: A video or an audio file.
    ///   - language: The language spoken, as a code.
    /// - Returns: The words, and the recording's length.
    /// - Throws: ``DubError/noAudio(_:)``, ``DubError/nothingHeard(_:)``.
    public static func listen(to url: URL, language: String) async throws -> (words: [TimedWord], duration: TimeInterval) {
        let asset = AVURLAsset(url: url)
        guard try await !asset.loadTracks(withMediaType: .audio).isEmpty else {
            throw DubError.noAudio(url.lastPathComponent)
        }
        let duration = try await asset.load(.duration).seconds
        let hasVideo = try await !asset.loadTracks(withMediaType: .video).isEmpty
        let options = TranscriptionOptions(locale: SpeechLocale.locale(for: language), segmentation: .word)
        let transcript = hasVideo
            ? try await SpeechTranscriber.transcribe(videoURL: url, options: options)
            : try await SpeechTranscriber.transcribe(audioURL: url, options: options)
        let words = transcript.segments.map { TimedWord(text: $0.text, start: $0.start, end: $0.end) }
        guard !words.isEmpty else { throw DubError.nothingHeard(url.lastPathComponent) }
        return (words, duration)
    }

    // MARK: - Planning

    /// Hears a recording, splits it into lines and translates them.
    ///
    /// - Parameters:
    ///   - url: The recording.
    ///   - from: The language spoken.
    ///   - to: The language to dub into.
    ///   - translator: Which translator; `.auto` stays on this machine when
    ///     the pair is installed.
    /// - Returns: The plan, ready to voice or to edit.
    public static func plan(for url: URL, from: String, to: String,
                            translator: Translate.Engine = .auto) async throws -> DubPlan {
        let heard = try await listen(to: url, language: from)
        let lines = LineSplitter.lines(from: heard.words)
        let translated = try await translate(lines, from: from, to: to, translator: translator)
        return DubPlan(from: from, to: to, translator: translated.engine, duration: heard.duration,
                       lines: translated.lines)
    }

    /// Translates lines, one request each.
    ///
    /// One at a time rather than joined: a joined block comes back with its
    /// line breaks moved, and a translation landing in the wrong slot is
    /// worse than a slow one.
    ///
    /// - Returns: The lines with translations, and which engine did the work
    ///   ("apple", "google", or "apple+google" when it varied).
    public static func translate(_ lines: [DubLine], from: String, to: String,
                                 translator: Translate.Engine = .auto) async throws -> (lines: [DubLine], engine: String) {
        var out: [DubLine] = []
        var engines: Set<String> = []
        for var line in lines {
            do {
                let result = try await Translate.text(line.source, from: from, to: to, engine: translator)
                line.translation = result.text
                engines.insert(result.engine.rawValue)
            } catch {
                throw DubError.translationFailed(error.localizedDescription)
            }
            out.append(line)
        }
        return (out, engines.sorted().joined(separator: "+"))
    }

    // MARK: - Voicing

    /// Says every line, fits it to its slot, mixes it over the background
    /// and writes the result — a video with its soundtrack replaced, or an
    /// audio file.
    ///
    /// - Parameters:
    ///   - plan: The lines to say.
    ///   - source: The original recording.
    ///   - output: Where to write: the source's container for a video,
    ///     `.m4a` or `.wav` for sound.
    ///   - engine: The voice engine.
    ///   - voice: A voice, or nil for the engine's first in the plan's language.
    ///   - background: What plays underneath.
    ///   - maximumSpeed: The fastest a line may be spoken.
    /// - Returns: Where every line went and how well it fitted.
    public static func render(_ plan: DubPlan, source: URL, to output: URL,
                              engine: any TTSEngine, voice: TTSVoice? = nil,
                              background: Background = .voiceOver,
                              maximumSpeed: Double = SlotFitter.defaultMaximumSpeed) async throws -> DubResult {
        try validate(plan)
        try await engine.prepare()
        var options = SynthesisOptions()
        options.language = plan.to
        if let voice {
            options.voice = voice
        } else {
            options.voice = try await engine.availableVoices().first { $0.language.lowercased().hasPrefix(plan.to.lowercased()) }
        }

        // Every line at its natural pace, resampled to the mix rate.
        var natural: [[Float]] = []
        for line in plan.lines {
            do {
                let spoken = try await engine.synthesize(line.translation, options: options)
                natural.append(try AudioIO.resample(spoken.samples, from: spoken.sampleRate, to: AudioIO.mixRate))
            } catch let error as DubError {
                throw error
            } catch {
                throw DubError.synthesisFailed(error.localizedDescription)
            }
        }

        let placements = SlotFitter.place(plan.lines, naturalDurations: natural.map { Double($0.count) / AudioIO.mixRate },
                                          recordingDuration: plan.duration, maximumSpeed: maximumSpeed)
        let clips = try zip(natural, placements).map { samples, placement in
            TrackMixer.Clip(samples: try TimeStretcher.stretch(samples, sampleRate: AudioIO.mixRate, speed: placement.speed),
                            start: placement.start)
        }

        let length = Int((plan.duration * AudioIO.mixRate).rounded())
        let bed: [[Float]], gain: Float
        switch background {
        case .none: (bed, gain) = ([], 0)
        case .original(let level): (bed, gain) = (try await AudioIO.decode(source), level)
        case .samples(let samples, let level): (bed, gain) = (samples, level)
        }
        let mix = TrackMixer.mix(clips, background: bed, backgroundGain: gain, length: length, sampleRate: AudioIO.mixRate)

        let audioOnly = try await AVURLAsset(url: source).loadTracks(withMediaType: .video).isEmpty
        if audioOnly {
            try AudioIO.write(mix, to: output)
        } else {
            let soundtrack = FileManager.default.temporaryDirectory
                .appendingPathComponent("dub-\(UUID().uuidString).m4a")
            defer { try? FileManager.default.removeItem(at: soundtrack) }
            try AudioIO.write(mix, to: soundtrack)
            try await Muxer.replaceAudio(of: source, with: soundtrack, to: output)
        }
        return DubResult(plan: plan, placements: placements, output: output, audioOnly: audioOnly)
    }

    // MARK: - Checking

    /// Hears a dub again and scores it against what it was meant to say.
    ///
    /// - Parameters:
    ///   - url: The dubbed file.
    ///   - plan: The plan it was made from.
    /// - Returns: The share of the translated words heard again, in order, 0–1.
    public static func verify(_ url: URL, plan: DubPlan) async throws -> Double {
        let heard = try await listen(to: url, language: plan.to)
        return Agreement.score(intended: plan.lines.map(\.translation).joined(separator: " "),
                               heard: heard.words.map(\.text).joined(separator: " "))
    }

    /// Refuses a plan whose lines are out of order, overlap, fall outside
    /// the recording or have nothing to say — the shapes an edited plan
    /// arrives in when the edit went wrong.
    static func validate(_ plan: DubPlan) throws {
        guard !plan.lines.isEmpty else { throw DubError.invalidPlan("it has no lines") }
        for (index, line) in plan.lines.enumerated() {
            guard line.end > line.start, line.start >= 0, line.start <= plan.duration else {
                throw DubError.invalidPlan("line \(index + 1) runs from \(line.start)s to \(line.end)s")
            }
            guard !line.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DubError.invalidPlan("line \(index + 1) has no translation")
            }
            if index > 0, line.start < plan.lines[index - 1].start {
                throw DubError.invalidPlan("line \(index + 1) starts before line \(index)")
            }
        }
    }
}
