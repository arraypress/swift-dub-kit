//
//  DubKitTests.swift
//  DubKitTests
//
//  Created by David Sherlock on 2026.
//
//  The decisions a dub makes, with known numbers: where lines break, where
//  each dubbed line goes and how fast, how the mix is built, and how a
//  second listen is scored. The voices and the recogniser are exercised in
//  the end-to-end suite, which needs this Mac's speech models.
//

import AVFoundation
import Foundation
import SpeechSynthesizer
import Testing
@testable import DubKit

/// Words one second apart, each 0.8 s long, with a given gap before chosen ones.
private func words(_ text: String, gapsBefore: [Int: Double] = [:]) -> [TimedWord] {
    var time = 0.0
    return text.split(separator: " ").enumerated().map { index, word in
        time += gapsBefore[index] ?? 0
        defer { time += 1 }
        return TimedWord(text: String(word), start: time, end: time + 0.8)
    }
}

@Suite("Where lines break")
struct LineSplitterTests {

    @Test("A pause ends a line")
    func pause() {
        let lines = LineSplitter.lines(from: words("so today compressors the attack sets", gapsBefore: [3: 1.0]))
        #expect(lines.map(\.source) == ["so today compressors", "the attack sets"])
        #expect(lines[1].start == 4.0)
    }

    @Test("Sentence punctuation ends a line when the recogniser gives it")
    func punctuation() {
        #expect(LineSplitter.lines(from: words("Hello there. General Kenobi")).map(\.source)
                == ["Hello there.", "General Kenobi"])
    }

    @Test("A run-on line breaks at its widest gap, not mid-phrase")
    func longest() {
        // 14 words, 1 s apart: past 12 s it must break, and the one wider
        // gap (before word 6) is where.
        let stream = words("a b c d e f g h i j k l m n", gapsBefore: [6: 0.3])
        let lines = LineSplitter.lines(from: stream, pause: 1, longest: 12)
        #expect(lines.count == 2)
        #expect(lines[0].source == "a b c d e f")
    }

    @Test("Fillers are dropped before translating, punctuation or not")
    func fillers() {
        let kept = LineSplitter.withoutFillers(words("Um, the attack Ah sets uh"))
        #expect(kept.map(\.text) == ["the", "attack", "sets"])
    }

    @Test("Fluent speech timed end to end splits into halves, not single words")
    func contiguous() {
        // 60 words, 0.3 s each, no gap at all — how Apple times a fluent speaker.
        let stream = (0..<60).map { TimedWord(text: "w\($0)", start: Double($0) * 0.3, end: Double($0 + 1) * 0.3) }
        let lines = LineSplitter.lines(from: stream)
        #expect(lines.allSatisfy { $0.duration >= 3 }, "\(lines.map(\.duration))")
        #expect(lines.allSatisfy { $0.duration <= LineSplitter.defaultLongest })
        #expect(lines.map { $0.source.split(separator: " ").count }.reduce(0, +) == 60, "no word lost")
    }

    @Test("A dropped filler is not a pause")
    func fillerIsNotAPause() {
        // "reacts Ah and": the Ah sits in the middle of a breath.
        let stream = [TimedWord(text: "reacts", start: 7.86, end: 8.34), TimedWord(text: "Ah", start: 8.40, end: 8.94),
                      TimedWord(text: "and", start: 8.94, end: 9.12)]
        #expect(LineSplitter.lines(from: LineSplitter.withoutFillers(stream)).count == 1)
    }

    @Test("A filler after a pause does not bridge it")
    func fillerAfterPause() {
        let stream = [TimedWord(text: "compressors", start: 1.56, end: 2.58), TimedWord(text: "Um", start: 5.10, end: 5.70),
                      TimedWord(text: "the", start: 5.70, end: 5.94)]
        #expect(LineSplitter.lines(from: LineSplitter.withoutFillers(stream)).count == 2)
    }

    @Test("No words, no lines")
    func empty() {
        #expect(LineSplitter.lines(from: []).isEmpty)
    }
}

@Suite("Where dubbed lines go")
struct SlotFitterTests {

    let lines = [DubLine(start: 0, end: 3, source: "a"), DubLine(start: 5, end: 8, source: "b")]

    @Test("A line that fits is left alone, at its original start")
    func fits() {
        let placed = SlotFitter.place(lines, naturalDurations: [3, 2], recordingDuration: 10)
        #expect(placed[0].speed == 1)
        #expect(placed[0].start == 0)
        #expect(placed.allSatisfy { $0.fits })
    }

    @Test("A long line borrows the pause after it before it is sped up")
    func borrows() {
        // The slot runs to 5 - 0.15 = 4.85 s; 4.5 s fits without speeding up.
        let placed = SlotFitter.place(lines, naturalDurations: [4.5, 2], recordingDuration: 10)
        #expect(placed[0].speed == 1)
        #expect(placed[0].fits)
    }

    @Test("A line too long for its slot is sped up just enough")
    func speeds() {
        let placed = SlotFitter.place(lines, naturalDurations: [5.82, 2], recordingDuration: 10)
        #expect(abs(placed[0].speed - 5.82 / 4.85) < 0.0001)
        #expect(abs(placed[0].end - 4.85) < 0.0001)
        #expect(placed[0].fits)
    }

    @Test("Past the speed cap the overrun is reported and the next line waits")
    func overruns() {
        let placed = SlotFitter.place(lines, naturalDurations: [9.7, 2], recordingDuration: 10, maximumSpeed: 1.5)
        #expect(placed[0].speed == 1.5)
        #expect(abs(placed[0].overrun - (9.7 / 1.5 - 4.85)) < 0.0001)
        #expect(!placed[0].fits)
        #expect(abs(placed[1].start - (placed[0].end + SlotFitter.defaultGap)) < 0.0001)
        #expect(placed[1].delay > 0)
    }

    @Test("The last line's slot is the end of the recording")
    func last() {
        let placed = SlotFitter.place(lines, naturalDurations: [2, 6], recordingDuration: 10)
        #expect(abs(placed[1].speed - 6.0 / 5.0) < 0.0001)
    }
}

@Suite("The mix")
struct MixerTests {

    @Test("A clip lands at its start, in both channels, over the background")
    func places() {
        let mix = TrackMixer.mix([.init(samples: [0.5, 0.5], start: 1)], background: [[0.1, 0.1, 0.1, 0.1], [0.2, 0.2, 0.2, 0.2]],
                                 backgroundGain: 0.5, length: 4, sampleRate: 2)
        #expect(mix[0] == [0.05, 0.05, 0.55, 0.55])
        #expect(mix[1] == [0.1, 0.1, 0.6, 0.6])
    }

    @Test("A mix that would clip is turned down, not squared off")
    func neverClips() {
        let mix = TrackMixer.mix([.init(samples: [0.9, 0.9], start: 0)], background: [[0.9, 0.0], [0.9, 0.0]],
                                 backgroundGain: 1, length: 2, sampleRate: 1)
        #expect(abs(mix[0][0] - 0.99) < 0.0001)
        #expect(abs(mix[0][1] - 0.9 * 0.99 / 1.8) < 0.0001, "the quieter sample keeps its proportion")
    }
}

@Suite("Audio")
struct AudioTests {

    @Test("Stretching lands on the exact length")
    func stretch() throws {
        let tone = (0..<44_100).map { Float(sin(Double($0) * 2 * .pi * 220 / 44_100)) * 0.3 }
        for speed in [1.2, 1.5] {
            let out = try TimeStretcher.stretch(tone, sampleRate: 44_100, speed: speed)
            #expect(out.count == Int((44_100 / speed).rounded()))
        }
        let untouched = try TimeStretcher.stretch(tone, sampleRate: 44_100, speed: 1)
        #expect(untouched == tone)
    }

    @Test("Resampling keeps the length in seconds")
    func resample() throws {
        let second = [Float](repeating: 0.1, count: 22_050)
        let out = try AudioIO.resample(second, from: 22_050, to: 44_100)
        #expect(abs(out.count - 44_100) < 64)
    }

    @Test("What is written reads back at the mix rate and length", arguments: ["m4a", "wav"])
    func roundTrip(ext: String) async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dubkit-\(UUID().uuidString).\(ext)")
        defer { try? FileManager.default.removeItem(at: url) }
        let frames = 44_100
        try AudioIO.write([[Float](repeating: 0.2, count: frames), [Float](repeating: -0.2, count: frames)], to: url)
        let back = try await AudioIO.decode(url)
        #expect(back.count == 2)
        #expect(abs(back[0].count - frames) < 4096, "AAC pads by a frame or two, no more")
        #expect(abs(back[0][frames / 2] - 0.2) < 0.01, "left stays left")
        #expect(abs(back[1][frames / 2] + 0.2) < 0.01, "and right stays right")
    }
}

@Suite("The second listen")
struct AgreementTests {

    @Test("Accents, case and punctuation are not misses")
    func normalises() {
        #expect(Agreement.score(intended: "La compresión, rápida.", heard: "la compresion rapida") == 1)
    }

    @Test("One misheard word costs one word")
    func oneWord() {
        #expect(Agreement.score(intended: "uno dos tres cuatro", heard: "uno dos tres cinco") == 0.75)
    }

    @Test("Nothing heard is nothing")
    func nothing() {
        #expect(Agreement.score(intended: "uno dos", heard: "") == 0)
    }
}

@Suite("Plans")
struct PlanTests {

    @Test("A bare language code gets the commonest region")
    func locales() {
        #expect(SpeechLocale.locale(for: "es").identifier == "es-ES")
        #expect(SpeechLocale.locale(for: "pt_BR").identifier == "pt-BR")
    }

    @Test("An edited plan with a line out of order is refused")
    func refusesDisorder() {
        let plan = DubPlan(from: "en", to: "es", translator: "edited", duration: 10, lines: [
            DubLine(start: 5, end: 6, source: "b", translation: "b"),
            DubLine(start: 1, end: 2, source: "a", translation: "a"),
        ])
        #expect(throws: DubError.self) { try Dubber.validate(plan) }
    }

    @Test("A line with no translation is refused")
    func refusesBlank() {
        let plan = DubPlan(from: "en", to: "es", translator: "edited", duration: 10,
                           lines: [DubLine(start: 1, end: 2, source: "a", translation: " ")])
        #expect(throws: DubError.self) { try Dubber.validate(plan) }
    }

    @Test("A plan survives a round trip through JSON")
    func codable() throws {
        let plan = DubPlan(from: "en", to: "es", translator: "apple", duration: 10,
                           lines: [DubLine(start: 1, end: 2, source: "hello", translation: "hola")])
        let decoded = try JSONDecoder().decode(DubPlan.self, from: JSONEncoder().encode(plan))
        #expect(decoded == plan)
    }
}

@Suite("Which voice says it")
struct VoicePickerTests {

    private func apple(_ id: String, _ language: String) -> TTSVoice {
        TTSVoice(id: id, name: id, language: language, model: .apple)
    }

    @Test("A downloaded premium voice beats the compact one listed first")
    func premiumFirst() {
        let voices = [apple("com.apple.voice.compact.es-ES.Monica", "es-ES"),
                      apple("com.apple.eloquence.es-ES.Grandma", "es-ES"),
                      apple("com.apple.voice.enhanced.es-ES.Monica", "es-ES"),
                      apple("com.apple.voice.premium.es-ES.Marisol", "es-ES")]
        #expect(VoicePicker.best(of: voices, for: "es")?.id == "com.apple.voice.premium.es-ES.Marisol")
    }

    @Test("The smallest voice still beats a novelty one, and order breaks ties")
    func noveltyLast() {
        let voices = [apple("com.apple.eloquence.ru-RU.Rocko", "ru-RU"),
                      apple("com.apple.voice.super-compact.ru-RU.Milena", "ru-RU")]
        #expect(VoicePicker.best(of: voices, for: "ru")?.id == "com.apple.voice.super-compact.ru-RU.Milena")
        let two = [apple("com.apple.voice.compact.es-ES.Monica", "es-ES"), apple("com.apple.voice.compact.es-MX.Paulina", "es-MX")]
        #expect(VoicePicker.best(of: two, for: "es")?.name == "com.apple.voice.compact.es-ES.Monica")
    }

    @Test("An engine with no voice in the language offers none — Kokoro has no Spanish here")
    func noneInLanguage() {
        let kokoro = [TTSVoice(id: "af_heart", name: "Heart", language: "en-US", model: .kokoro)]
        #expect(VoicePicker.best(of: kokoro, for: "es") == nil)
        #expect(VoicePicker.best(of: kokoro, for: "en")?.id == "af_heart")
    }
}
