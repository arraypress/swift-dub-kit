//
//  TTSVoice+Tier.swift
//  DubKit
//
//  Created by David Sherlock on 2026.
//

import SpeechSynthesizer

extension TTSVoice {
    /// ``VoicePicker``'s rank for this voice, best first.
    var tier: Int { VoicePicker.tier(of: id) }
}
