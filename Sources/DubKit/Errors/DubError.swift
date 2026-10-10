//
//  DubError.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//
//  Failures a caller can act on, each naming what was wrong.
//

import Foundation

/// Why a dub could not be made.
public enum DubError: Error, LocalizedError, Sendable, Equatable {
    /// The recording has no sound to hear.
    case noAudio(String)
    /// The recogniser heard no words.
    case nothingHeard(String)
    /// A line could not be translated.
    case translationFailed(String)
    /// A line could not be spoken.
    case synthesisFailed(String)
    /// The audio could not be decoded, mixed or written.
    case audioFailed(String)
    /// The video and the new sound could not be put together.
    case exportFailed(String)
    /// A plan's lines are out of order, overlap, or fall outside the recording.
    case invalidPlan(String)
    /// The engine has no voice in the language to dub into.
    case noVoice(String)

    /// A lowercase phrase that reads inside a sentence, for a CLI or a log.
    public var errorDescription: String? {
        switch self {
        case .noAudio(let name): return "\(name) has no sound to dub"
        case .nothingHeard(let name): return "no speech was recognised in \(name)"
        case .translationFailed(let why): return "a line could not be translated: \(why)"
        case .synthesisFailed(let why): return "a line could not be spoken: \(why)"
        case .audioFailed(let why): return "the audio could not be made: \(why)"
        case .exportFailed(let why): return "the dub could not be written: \(why)"
        case .invalidPlan(let why): return "the plan is not usable: \(why)"
        case .noVoice(let language): return "no voice speaks \(language)"
        }
    }
}
