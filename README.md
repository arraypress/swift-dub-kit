# swift-dub-kit

Dub a video or a recording into another language **on this machine**: hear it,
translate it, say it in a new voice, fit every line to the picture, and put it
back. No key. Translation stays on the Mac whenever Apple's model for the pair is
installed (hundreds of pairs on a stock macOS 27); otherwise Google's keyless web
endpoint is used and the plan says so.

```swift
import DubKit
import SpeechSynthesizer

let plan = try await Dubber.plan(for: talk, from: "en", to: "es")   // hear + translate
// … write it out, correct a name, read it back — it is Codable …
let result = try await Dubber.render(plan, source: talk, to: dubbed,
                                     engine: AppleEngine(), background: .voiceOver)
result.overrunning                     // lines that did not fit even at the cap
try await Dubber.verify(dubbed, plan: plan)   // 0–1: the translation heard again
```

## The hard part: fitting

A translation is almost never the length of what it translates — Spanish ran
**40% longer** than the English it came from on the first probe (10.4 s for
7.4 s). Each line gets a slot: from where the original line started to just
before the next one does, so it borrows the pause after it. A line that still
does not fit is sped up with `AVAudioUnitTimePitch` — pitch kept — never past the
cap; what is left is an **overrun**, which pushes the next line back and is
reported, never hidden.

Measured, and the numbers behind each choice:

- **The synthesiser's own rate stops helping early.** Apple's voices said the
  same Spanish line in 9.64 s at rate 0.6 and at rate 0.7. So lines are spoken at
  their natural pace and stretched afterwards.
- **Stretching is exact.** Targets of 90%, 80% and 70% landed to the sample, and
  the recogniser read the 70% version word for word.
- **The cap, 1.5×, is a listening judgement, not a measurement.** Apple's
  recogniser still read five lines each of Spanish, French and German at 92–97%
  after a 1.6× speed-up and 90–97% at 1.8× (Spanish fell to 81% at 2×). A
  recogniser is a better listener than a person; 1.8× sounds hurried.
- **Fillers are dropped before translating** ("um", "uh", and "ah" — Apple's
  recogniser writes a spoken "uh" as "Ah", 2 of 2), and a dropped filler's time is
  folded into the word before it. Left as a hole it read as a pause, split a
  sentence, and the translator turned "the release" alone into *el lanzamiento*,
  a product launch.

## On real speech

Two public-domain recordings from archive.org: four minutes of a NASA crew
interview (STS-133, studio, a fluent speaker) and five minutes of a 1985 oral
history (Hanford Mills Museum, Public Domain Mark). Apple voices, translation on
this Mac, `.voiceOver` bed.

**The first run was a failure, and found a bug.** Apple's recogniser times
words end to end — in fluent speech every gap is zero — so the 12-second rule
broke a long run at its first tied "widest gap", cut one word off, stayed too
long, and did it again on the next word. The interview became 94 lines, most of
them one word with a slot of a fraction of a second:

| Interview, 4:00 | 0.1.0 | split at the middle |
|---|---|---|
| Lines | 94 (median 0.3 s) | 33 (median 6.8 s) |
| Spanish: overrunning, latest start, heard | 69, 16.4 s late, 94% | **0**, on time, **98.2%** (fastest 1.29×) |
| French | 74, 21.0 s late, 79.8% | 1 (0.7 s), **92.7%** |
| German | 76, 14.7 s late, 85.4% | 9 (worst 1.4 s), **93.1%** |
| Oral history → Spanish | — | 45 lines, 0 overrunning, 93.7% |

A dub of four to five minutes takes 45–60 s on this Mac, most of it the two
listens. German runs longest — even split properly, 30 of 33 lines needed
speeding up and 9 still overran at 1.5×; shortening those lines in the plan is
the lever. Not measured: how the dubs sound to a person.

## What plays underneath

`Background.voiceOver` keeps the original at −18 dB; `.none` drops it;
`.samples(_:gain:)` takes a bed the caller prepared — the original with its voice
separated out, which keeps the music and the room. Measured in a pause of a
speech-over-music recording: original 1379 RMS, separated bed 1380, voice-over
172 (exactly ⅛), none 0. The separation model is not in this library; `redub`
uses the one `stems` installs.

## The second listen

`verify` recognises the dub in the target language and scores it against the
translation by word diff (TextDiff, one word per line — its word mode counts the
spaces too, which scored 3 of 4 words as 6 of 7). Case, accents and punctuation
are set aside. On the probes: 89% with a filler-laden plan, 100% after fillers
were dropped or the plan corrected.

## Layout

`Core/Dubber` (listen → plan → render → verify) · `Support/` LineSplitter,
SlotFitter, TimeStretcher, AudioIO, TrackMixer, Muxer (video passthrough, new
AAC track), Agreement, SpeechLocale · `Models/` TimedWord, DubLine, DubPlan,
Placement, DubResult · `Enums/` Background · `Errors/` DubError.

Measured on synthetic speech (`say`) and a synthetic video; **real recordings of
people are not measured yet.**

## Requirements

macOS 26 / iOS 26, Swift 6.2.

## License

MIT — see [LICENSE](LICENSE).
