# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][1], and this project adheres to
[Calendar Versioning][2] using `YYYY.MM.DD` release identifiers.

[1]: https://keepachangelog.com/en/1.1.0/
[2]: https://calver.org/

## [Unreleased]

### Added

- Ensemble mode now names rootless voicings as the chords they imply when
  comping with a bassist. For example, E-B♭-D-A is named C13 and marked
  "rootless" instead of receiving a strained slash-chord name. Ensemble mode
  also recognizes secondary dominants, tritone substitutions, and other
  outside-the-key chords.
- Switch between Solo and Ensemble under Playing Mode in Settings. A badge in
  the tonality bar shows when Ensemble mode is active, and the keyboard marks
  the implied root with a hollow key. Shared chord links preserve the playing
  mode, and the website's Try page includes the same toggle.
- A new Scale Degree Guide on the website explains degree names and formulas,
  Roman numerals, and how scales are harmonized into chords.

### Changed

- "Why This Chord?" now uses shorter, friendlier explanations for why each chord
  name ranks above the next option.
- Chord naming now uses the current key to resolve common sixth-versus-seventh
  ambiguities. In C major, D-F-A-C over an F bass is named Dm7/F rather than F6,
  while tonic sixth chords such as C6 keep their familiar names.
- Automatic key detection now responds to a clear first chord and follows
  authentic cadences and modulations sooner. New installations default to
  Balanced behavior; existing behavior preferences are unchanged.
- Ensemble mode uses a faster internal reading of the current key so rootless
  chord names keep up with modulations without making the visible key indicator
  more reactive. Manually selected keys continue to govern naming directly.
- Recent Chords can revise the previous chord after a key change or resolution
  clarifies its meaning, including ambiguous rootless flat-nine dominants. The
  corrected chip flips to its new name in place.
- The tonality bar uses a more compact key button and tighter scale-degree
  spacing on narrow screens.
- Six-sharp keys are now labeled F♯ major instead of G♭ major, producing the
  expected F♯ spellings in chord names.

### Fixed

- Connecting to a Bluetooth MIDI device that has lost its pairing now explains
  how to forget the device in system Bluetooth settings and pair it again.
- Google Play download links now open WhatChord's public production listing.

## [2026.7.20] - 2026-07-20

### Added

- Bluetooth MIDI devices now reconnect automatically after an unexpected
  dropout. If a device is powered off or moves out of range, turning it back on
  within the retry window reconnects it without any taps.

### Changed

- Chord symbols now distinguish accidentals on roots from altered extensions, so
  compact names such as C(♯11) and C♯(11) are easier to read correctly.
- Bluetooth MIDI connections now complete about a second faster by relying on
  the MIDI engine's readiness checks instead of repeating them in the app.
- Bluetooth MIDI pairing, connection, and disconnection are more reliable after
  updating the MIDI engine and removing old compatibility workarounds.
- Reduced background Bluetooth activity while connected by checking for silent
  dropouts once a minute instead of every 16 seconds. Most dropouts are still
  detected immediately.

### Fixed

- Connection failures now explain what went wrong and what to do next, such as a
  declined pairing request or a device without Bluetooth MIDI support, instead
  of a generic "Failed to connect" message.
- Connecting and reconnecting to Bluetooth MIDI adapters now succeeds on the
  first attempt by waiting for the device to reappear during scanning.
- Toggling Bluetooth off and on during a reconnect attempt no longer leaves the
  app disconnected.
- Improved recognition of rare altered major-seventh flat-nine colors so they
  are less likely to displace simpler common-shell readings unless the voicing
  strongly supports them.
- Scale Explorer previews now keep single-note chord highlights in sync with the
  note being played.
- Fixed the website landing page on phones so its text is no longer squeezed
  beside the screenshot.
- "Reset all settings" now also resets the Scale Explorer's Show Scale Degrees
  preference.

## [2026.7.11] - 2026-07-11

### Added

- Automatic key detection. Open the Key Signature page from the key button and
  switch to Auto to follow the chords you play, with a confidence readout,
  circle-of-fifths view, and recent-chords list. The key button updates live,
  fades as evidence ages, and shows when the result is uncertain. Choosing a key
  manually always returns to Manual mode.
- A Key Detection behavior setting in Settings. Choose Stable, Balanced, or
  Reactive to favor a settled song key or more closely follow changes in tonal
  center. Faster modes also clear their result sooner after you stop playing.

### Fixed

- The piano keyboard recenters on active notes (or middle C when idle) after
  rotating the device or resizing the window, instead of sometimes ending up
  scrolled to an unexpected octave.

## [2026.7.6] - 2026-07-06

### Added

- Power chords are now named directly for bare root-and-fifth voicings, such as
  C5, C5/G, and C5(add♭9). Add a third or seventh and the usual triad or seventh
  chord reading still wins.
- Added a Chord Naming Guide to the website, covering interval names, chord
  formulas, slash bass, enharmonic spelling, and how possible roots are
  compared.
- Added website articles and tooling notes for chord ranking performance,
  recognition behavior, and the oracle-comparison workflow.
- Added benchmark regression checks, noise calibration, rule-ablation reports,
  and pool-diff tooling for tracking chord-analysis behavior and performance.

### Changed

- Rebuilt chord ranking around explanation cost. A chord name now pays for what
  it must explain: uncommon vocabulary, color tones, missing essential tones,
  unexplained notes, and awkward bass placement. Lower cost is better, which
  makes results line up more naturally with musician expectations.
- Common, readable chord names now win more often unless a rarer name explains
  the voicing decisively better. This reduces exotic altered-fifth, minor-major,
  suspended, and chromatic bookkeeping labels in dense voicings.
- Chord identification is now roughly 15x faster on common everyday chords and
  about 24x faster across the oracle benchmark, including dense or ambiguous
  voicings with many possible readings.
- Possible alternatives now track the app-visible near-tie set more directly, so
  alternatives are focused on musically close readings instead of incidental
  candidates from the full ranking list.
- Rare chord vocabulary such as m♯5, maj♭5, 7sus2, maj7sus2, m7♯5, maj7♭5, and
  maj7♯5 now needs a stronger musical fit before it can displace common chord
  names.
- Slash bass notes now favor readable sounding-pitch spellings when the bass is
  a color or altered tone, so A7♯9/C is preferred over A7♯9/B♯. Ordinary
  chord-tone inversions such as A/C♯, F♯7/A♯, and C♯maj7/B♯ are unchanged.
- Close ties now prefer cleaner contextual spelling instead of falling back to
  arbitrary root order, especially for tritone-related dominants and dense
  altered or Lydian voicings.
- Explore copy dialogs, website chord results, and article examples now use
  hyphenated note lists such as C-E-G while keeping chord degrees
  comma-separated.
- The website now has an article index, cleaner article URLs, a mobile hamburger
  menu, external-link markers, stronger print layouts, and improved 404-page
  asset loading.

### Fixed

- Fixed an iOS issue where some Bluetooth MIDI devices, such as dedicated MIDI
  adapters that skip system-level pairing, would connect successfully but never
  deliver any notes.
- Switching between MIDI devices now closes the previous connection. It was left
  open before, so the prior device could keep feeding notes alongside the newly
  selected one.
- Improved note handling for Bluetooth MIDI controllers that use running status,
  a common way to save bandwidth by omitting the repeated status byte between
  messages. These notes were previously ignored, so fast or chord-dense playing
  could drop notes; they are now read correctly.
- Fixed connection timing around the updated MIDI plugin so slow-but-valid
  connections are not aborted early or left orphaned in the background.
- Improved dominant, altered-dominant, and tritone-dominant recognition,
  including C7♯5♭9, A7♯5♯9/C, D9♭5/C, C9♭9/D♭, D9/C, and D7/E-style voicings.
- Improved Lydian, sharp-eleventh, and upper-structure slash recognition,
  including D♭maj7♯11, G♭♯11/D♭, and D♭maj7/E♭-style voicings.
- Improved minor-ninth, minor-sixth, minor-major, and diminished recognition, so
  complete shells and stable bass roles are less likely to be displaced by
  remote chromatic reinterpretations.
- Improved add-chord and split-ninth triad recognition, so complete triads such
  as C(add♭9,add9), Cadd9/E, and add-eleven slash voicings are easier to read.
- Fixed website layout issues around article cards, printed chord results,
  printed articles, and mobile navigation.

## [2026.6.28] - 2026-06-28

### Added

- Explore Chords and Explore Scales now show the notes you are playing live on
  the keyboard whenever an example is not currently sounding.
- Audio Monitor can now send Explore chord and scale previews to a connected
  MIDI instrument. Switch between Internal and MIDI Out playback, with separate
  remembered volume levels for each output. MIDI Out starts at a quieter
  default, follows the same mute control, and never echoes the live notes you
  play back to the instrument.
- Explore Scales can now copy scale details. Tap the scale name to copy the
  scale name, tones, formula (such as 1, 2, ♭3, 4, 5, ♭6, ♭7), or diatonic
  chords. Copied diatonic chords follow the 7ths toggle.
- Explore Chords can now copy the chord degree formula, such as 1, ♭3, 5, ♭7,
  matching the degree view available on the member chips.

### Changed

- Explore pages now include the MIDI status button in the top bar. Explore
  Chords shows non-chord live notes with a muted gray highlight, and Explore
  Scales does the same for out-of-scale notes against the selected scale
  markers.
- Chord symbols now follow more conventional formatting rules for extensions,
  modifiers, slash bass, and minor-major chords. This includes C13 instead of
  C7(add13), C9(♭5,♭9) instead of C9♭5♭9, minor-major labels such as Cm(maj7),
  compact copied slash symbols such as C/E, and parenthesized add tones after
  spelled-out aug and dim qualities, such as Caug(add9) and Cdim(add9).
- Simplified the Playback Volume control. The mute button now sits inline beside
  the slider, volume moves in predictable 5% steps, and the readout shows
  "Muted" while muted.
- Explore Scales now opens a chord in Explore from a button on the selected
  degree row, next to its play button, instead of a header icon detached from
  the selected chord.
- Why This Chord? now distinguishes the Chosen, Possible, and Unlikely ranking
  tiers more clearly. Each tier uses a distinct marker and rank badge, with a
  filled badge for the chosen chord, an outlined badge for possible
  alternatives, and a plain badge for unlikely ones.

### Fixed

- Improved identification of extended dominants, including 13ths, 9♭13s, 13♯11s,
  13♭5s, and altered 13♯9♯11 voicings. Complete dominant structures are now more
  likely to win over remote minor-six, diminished, minor-major, or Lydian-major
  reinterpretations.
- Improved slash-chord ranking so the bass role is weighted more musically.
  Complete add-nine triad inversions, major-seventh-bass inversions,
  seventh-bass dominants, ninth-bass dominants, and root-position sus or minor
  6/9 chords now surface more consistently.
- Improved half-diminished, diminished, and minor-major naming around close
  chromatic voicings, favoring clearer root-position or complete-shell labels
  while keeping real ambiguities available as alternatives.
- Improved altered-fifth and split-ninth dominant handling, including clearer
  9♯5, 9♭5, 7♭9♯9, and tritone-related flat-five spellings.
- Updated analysis diagnostics, chord-debug output, website examples, and
  reviewed oracle notes to match the current chord-symbol and ranking behavior.

## [2026.6.19] - 2026-06-19

### Added

- Added a resizable on-screen keyboard. Pinch to widen the keys, drag the handle
  above the bottom bar to make the keyboard taller, and keep the same size
  across Home, Explore Chords, and Explore Scales. Long-press the keyboard for
  quick recenter and reset actions, or double-tap the handle to reset.
- Live MIDI identification now reads register. When a complete chord is played
  above an isolated bass note, the upper-structure slash name (such as Am7/D) is
  surfaced as the primary reading, with the close alternatives still listed.
- Added a Chord Symbol Guide, linked from Help & Support and the website's chord
  identifier, explaining WhatChord's notation and formatting conventions.

### Changed

- Refined chord-symbol typography in the app and on the website, including
  clearer diminished and half-diminished marks and engraved chord glyphs in more
  places.
- Improved the website chord symbol guide with a hosted reference page, section
  links, tighter article spacing, clearer examples, and wording focused on how
  musicians read the symbols.
- Possible alternatives now stay rank-contiguous when hard rules reorder close
  chord candidates, so the visible alternatives list does not skip higher-ranked
  interpretations.
- The website chord identifier now states that typed notes are identified by
  pitch, not spelling.

### Fixed

- Opening a shared chord link now returns to the home screen, so the linked
  chord is shown even when the app was last left on an Explore page.
- Improved extended-chord identification, including fifthless major and dominant
  stacks, major-nine-suspended-fourth chords, Lydian major 6/9#11 sonorities,
  and Lydian-dominant slash chords.
- Improved altered-dominant identification, favoring complete dominant
  structures such as A13(#9,#11), Eb13#9, F9b13, C9#11/Bb, and F#7(b9,#11,b13)
  over less direct split-third, diminished, or remote slash spellings.
- Improved ambiguity handling for close dominant and major-family readings, so
  plausible alternatives such as F7b13 remain visible when they are musically
  useful.
- Improved identification of doubled-note voicings, so incomplete fifthless
  sixth chords no longer outrank clearer inverted minor or diminished chords.

## [2026.6.14] - 2026-06-14

### Added

- Added home-screen chord sharing. A shared link opens the exact voicing and key
  in WhatChord when installed, or in the website's chord identifier otherwise.
- Added a browser-based chord identifier to the website, powered by the same
  analysis engine as the app. Results can be shared, opened in the app, and
  previewed directly in supported messaging and social apps.
- Added a mute button to Playback Volume that remembers and restores the
  previous volume.
- Added more Explore Chords colors, including flat ninths for minor and
  suspended-fourth chords and flat thirteenths for applicable chords.
- Added chord tones to the Explore Chords copy menu.

### Changed

- Why This Chord? now begins with a clearer tone ledger showing played, missing,
  and additional notes by degree, and can open any ranked chord in Explore.
- Improved the guided tour's final step by pointing to both manual lookup and
  MIDI connection.

### Fixed

- Improved identification of major-family sharp-eleventh voicings, favoring
  direct Lydian chord names over remote slash-chord interpretations.
- Fixed note and root spellings disagreeing with the identified chord, including
  flat-rooted chords such as Bbmaj9 in C major.
- Fixed named extensions appearing as additional notes in chord details.
- Prevented contradictory natural- and flat-thirteenth selections in Explore
  Chords.
- Fixed an internal error when closing Settings after previewing Playback
  Volume.

## [2026.6.10] - 2026-06-10

### Added

- Added a manual chord lookup mode for identifying chords without a MIDI device.
  Tap notes by name to build a voicing, with the first note as the bass and
  repeated notes stacked into higher octaves.
- Added a guided first-launch tour of chord analysis, alternative readings, key
  context, and manual lookup. It can be replayed from Settings > Help & Support.
- Why This Chord? ranking cards can now reveal chord members, score
  contributions, and the decisions that determined their order.
- Expanded Explore Scales with practical dominant, harmonic-major, altered, and
  symmetric scales.

### Changed

- Playback Volume is now available when Audio Monitor is off and plays a short
  preview note while it is adjusted.
- Audio Monitor is now enabled by default for an audible first-run experience.
- The input note line now scrolls to keep newly played notes visible.
- Refined scale names and organization for clearer musical terminology.
- Resetting Settings to defaults now returns home and starts the guided tour.

### Removed

- Replaced Demo Mode and the first-launch MIDI prompt with the guided tour.

### Fixed

- Improved chord identification across ambiguous sixth, 6/9, minor seventh,
  minor eleventh, altered dominant, split-third, and inversion voicings,
  favoring familiar complete readings and using minor-key context where helpful.
- Recognized double-suspended voicings such as Gsus2sus4 directly.
- Presented stacked eleventh and thirteenth chords more conventionally when
  lower extensions are altered, such as B13(#9,#11).
- Improved guided-tour and manual-lookup behavior and positioning in landscape.

## [2026.6.6] - 2026-06-06

### Added

- Added Explore Scales, opened by tapping the scale-degree strip. It shows the
  selected scale's tones, scale-degree numbers, keyboard pattern, and diatonic
  chords, with playback for the full scale and individual chords.
- Explore Scales now includes common major and minor scales, diatonic modes,
  major and minor pentatonic scales, major and minor blues scales, whole-tone,
  augmented, diminished whole-half, and diminished half-whole scales.
- Explore Scales marks in-scale keyboard notes with dots, marks the tonic with a
  triangle, and highlights the selected chord. When a chord is selected, it also
  shows the chord's role in the key and, where appropriate, its expected
  resolution.
- Added a staff notation preview to the key signature picker, showing the
  selected signature with a treble clef.

### Changed

- Improved accidental and chord-symbol rendering across the app with bundled
  Inter and WhatChord Symbols fonts, giving note names, chord labels, and scale
  degrees more consistent typography on iOS and Android.
- Polished selection, list, chip, and segmented-control styling across Explore
  Scales, Explore Chords, Settings, and the key signature picker so selected
  rows and active controls feel more consistent.
- The Explore Chords root selector now lets you choose the exact enharmonic root
  spelling, such as C# versus Db. The chord symbol, note names, and scale-degree
  label all follow the selected spelling.
- Explore Scales now opens with smarter musical context from the current chord
  or Explore Chords selection, including matching diatonic degrees and harmonic
  minor when appropriate.
- Explore Scales now keeps selections steadier while changing tonics, switching
  between same-size scales, and moving among scale families.
- Tightened Explore note chip spacing so scale and chord tones with accidentals
  fit better on compact phones.
- Harmonic-minor scale-degree context now carries across the full degree strip
  when a chord is interpreted through harmonic minor, so labels such as V7 sit
  in a coherent minor-key context.
- Chord ranking now uses ChoCo corpus-derived common-name frequency as a narrow
  late tie-breaker for otherwise equivalent chord names, so voicings such as C D
  F A over A now prefer Dm7/A over F6/A.
- Marked main page titles, Explore Scales controls, and scale rows more clearly
  for assistive technologies.

### Fixed

- Fixed the Settings color palette picker throwing an exception when opened, so
  the picker once again shows the selected palette highlight.
- Fixed note chips shifting their neighbors by a hair when a note's outline
  thickened (such as when a note becomes sustained); the chips now hold a steady
  position.
- Fixed note chips shifting nearby chips when a note becomes filled and its text
  turns bold.
- Fixed copy dialog values being shortened with an ellipsis, so long copied
  values can wrap and remain readable.
- Fixed Explore Scales wheel positioning when the selected tonic spelling
  changes or the available tonic list gets shorter.
- Fixed piano keyboard auto-centering so active notes are followed a little
  sooner as they approach the edge of the visible keys.

### Removed

- Removed the "Show scale notes" setting and its key-top markers from the live
  analysis and chord views. Scale membership is now shown in the Scale Explorer,
  where in-scale notes are marked on the keyboard.

## [2026.6.1] - 2026-06-01

### Added

- Added a flat-ninth color choice for major triads in explore mode, so chords
  such as Cadd♭9 can be built directly.
- Added a visible copy button to explore mode so chord copy actions no longer
  depend on discovering a long-press gesture.

### Changed

- Improved chord identification and ranking for ambiguous slash chords, triad
  add-tone voicings, 6/9 chords, altered dominants, and voicings where every
  sounding note should be named.
- Prefer musician-expected triad add-tone names such as Caugadd9, Bbmadd9/Db,
  and B♭madd9/F over structurally weaker seventh-family, fifthless, or suspended
  readings of the same voicing.
- Prefer complete add9 inversions such as Cadd9/E over rarer minor-7-sharp-5
  respellings such as Em7#5 when the ordinary triad accounts for every pitch.
- Prefer root-position 6/9 names such as C6/9 over dominant-7-sus-slash readings
  like D7sus2/C for the same voicing, matching the conventional musician name.
- Prefer altered dominant seventh names such as F7(#9,b13)/Ab over competing
  non-dominant seventh-family slash readings of the same voicing.
- Prefer readings that name every sounding note over ones that silently drop a
  note. For example, C D♭ E G over a G bass is now read as a C major triad with
  a flat ninth rather than C#dim, which discarded the C.
- Compress redundant add-tone extensions from slash chord symbols when the slash
  bass already supplies that pitch (e.g., `Ab7(add11)/Db` → `Ab7/Db`, `Gadd9/A`
  → `G/A`).
- Name a flat ninth on a plain triad as an added tone, so C E G D♭ reads as
  Cadd♭9 rather than the ambiguous C♭9, matching how add9 and add#9 are already
  handled when no seventh is present.

### Fixed

- Fixed chord ranking so candidates are ordered consistently. The ranking rules
  intentionally override raw score, which made the underlying comparison
  non-transitive; sorting with it could occasionally bury a strong reading
  several places below a weaker one or, in rare cases, name the wrong chord.
  Rankings are now produced by a stable linearization that keeps every rule's
  verdict while guaranteeing a single, well-defined order.
- Fixed the near-tie alternatives list so a strong reading is no longer dropped
  when a hard rule promotes a lower-scoring chord to the top. Alternatives are
  now measured against the chosen chord's score, so readings that score at or
  above it stay visible instead of being suppressed.
- Fixed MIDI settings getting stuck on "Connecting..." with a disabled device
  list after disconnecting or forgetting a device. Disconnecting now stops
  reconnect attempts immediately and stays disconnected until you connect again.
- Fixed a race where disconnecting or cancelling while a connection was still
  being established could leave the device connected anyway.
- Fixed the Cancel button getting stuck on "Connecting..." when reconnecting to
  a Network Session that is no longer reachable. Cancel now always stops the
  attempt and returns to a disconnected state.
- Fixed chord root spelling so double-sharp and double-flat roots such as B𝄪 are
  never generated; enharmonic equivalents like C# are used instead.
- Fixed explore mode note chips so they spell members relative to the explicitly
  selected root, matching the chord symbol (e.g., C# major now shows C# E# G#
  instead of Db F Ab).
- Fixed explore mode copy dialog overflowing in landscape orientation.
- Fixed Android landscape spacing so the third chord alternative is no longer
  clipped, and extended the status-bar spacing adjustment to explore mode and
  settings pages.

## [2026.5.28] - 2026-05-28

### Added

- Added analysis and explore mode support for minor sharp-five and minor seventh
  sharp-five chords.
- Added split-third support, so voicings such as C-Eb-E-G can be named and
  explored as C(add#9), with member spelling that shows the mixed-third
  structure clearly.
- Added "Spoken name" to the long-press copy menu in explore mode, giving the
  idiomatic way musicians say a chord aloud (e.g., "G seven flat nine sharp
  eleven" instead of "G dominant seventh with flat nine and sharp eleven").
- Added research tooling for comparing WhatChord's analysis against external
  chord oracles, helping surface edge cases that need future tuning.

### Changed

- Improved chord identification and ranking for ambiguous slash chords,
  add-chords, suspended chords, altered colors, and inversion cases, with an
  emphasis on the names musicians are most likely to expect.
- Prefer complete major-triad inversions such as F#11/A over competing
  minor-sharp-five interpretations when the voicing strongly supports the
  inversion.
- Prefer bass-rooted dominant sus names such as D9sus4 over remote slash-chord
  reinterpretations.
- Prefer add-ninth, ninth-in-the-bass, and complete minor-seventh slash names
  such as G/A, C7/D, and Am7/D over less natural altered or remote-root
  alternatives.
- Identify sparse root-major-third-tritone voicings (e.g. Ab-C-D) as flat-five
  chords (Ab(b5)) rather than sharp-eleven extensions (Ab#11), matching the
  reading most musicians would expect.
- Display complete minor seventh chords over an eleventh bass more
  conventionally, such as Am7add11/D as Am7/D.
- Refined readable, spoken, and academic chord-name formatting so extended
  chords, slash chords, natural extensions, and multiple modifiers use more
  natural musician phrasing.
- Redesigned "Why This Chord?" so the modal always shows the top ranked
  candidates and explains the winning chord more directly.
- Kept Explore Chords member chips on one horizontally scrollable row to avoid
  layout jumps while changing chord options.

### Fixed

- Fixed explore mode extension controls so minor eleventh chords are easier to
  build, altered extensions preserve the rest of the selected stack, and
  duplicate added-thirteenth choices and hidden plain-triad extension
  implications are avoided.
- Fixed augmented chord spelling so readable roots such as Abaug are preferred
  over double-sharp member spellings.
- Fixed explore mode member chip transitions so changes are easier to follow
  while scrubbing through options.
- Fixed explore mode Harte notation copy so sharp root spellings such as C#m are
  preserved.

## [2026.5.23] - 2026-05-23

### Added

- Added a "Why This Chord?" alternatives view that explains why the current
  chord ranked above close alternatives.
- Added explore mode copy choices for chord symbol, readable name, and Harte
  notation export.
- Added a website article about validating WhatChord's chord vocabulary against
  a large public chord corpus.

### Fixed

- Fixed lydian-dominant chord ranking so voicings such as C-E-G-Bb-D-F# are
  identified as C9#11 instead of a remote altered-fifth slash chord.

## [2026.5.21] - 2026-05-21

### Added

- Added a Note Names setting for International, German, and Fixed-Do chord and
  note labels throughout the app.
- Added more Explore Chords altered-color choices, including sharp elevenths for
  minor and minor-sixth chords and flat ninths for sixth chords, with symbols
  such as Am#11 and Cm6b9.

### Changed

- Split Explore Chords quality controls into base quality, sixth or seventh, and
  fifth choices so longer chord lists are easier to scan.

### Fixed

- Fixed chord ranking so complete minor sharp-eleventh voicings are preferred
  over remote altered major-7-sus4 names.
- Fixed chord ranking so complete triads are preferred over incomplete inverted
  sixth-chord spellings in close ambiguities.
- Fixed Analysis Details copy actions so note names, chord symbols, members, and
  degree labels use the same accidentals as the rest of the interface.

## [2026.5.16] - 2026-05-16

### Added

- Added analysis support for more seventh-chord families, including suspended,
  flat-five, and augmented-fifth qualities such as 7sus2, maj7sus2, maj7sus4,
  7b5, maj7b5, 7#5, and maj7#5.
- Added long-press copy for the Explore Chords name and readable chord label.
- Added a project website with screenshots, feature overviews, and deeper
  articles about chord naming and the analysis pipeline.

### Changed

- Made highlighted black keys easier to read by matching their separators to the
  darker highlighted-key treatment used on white keys.
- Made explore mode easier to discover by adding chord-card guidance in Help &
  Support and project documentation.

### Fixed

- Fixed dominant sharp-ninth analysis so Hendrix-style voicings like G-B-D-F-A#
  are identified as 7#9 chords.
- Fixed chord ranking so conventional altered seventh names are preferred over
  questionable add11 slash-chord alternatives.
- Fixed Explore Chords dominant altered tones so flat ninth and sharp ninth can
  be selected together.
- Fixed Explore Chords preview voicings so A and B roots sit below middle C
  instead of above it.

## [2026.5.13] - 2026-05-13

### Added

- Added an Explore Chords toggle for switching chord member chips between note
  names and chord degrees.
- Added harmonic-minor scale-degree recognition so common minor-key functions
  like V7 and leading-tone diminished chords are identified alongside
  natural-minor functions.

### Changed

- Made Explore Chords extended examples more idiomatic, with clearer extension
  choices and preview voicings that better match common musician expectations.
- Made dominant seventh Explore controls distinguish headline extensions from
  exact added tones.
- Made Explore Chords root and quality scrubbers use wider layouts on larger
  screens without stretching individual choices.

### Fixed

- Fixed upper-extension chord analysis so lone elevenths use add11 naming and
  sharp-eleventh dominant thirteenths rank ahead of remote slash-chord readings.
- Fixed dominant add-thirteenth analysis so it stays distinct from full
  thirteenth chords.
- Fixed Audio Monitor event queuing so startup, previews, and live note playback
  are serialized more consistently, reducing the chance of rough first playback
  or stuck audio state.
- Fixed chord analysis caching so long sessions keep memory use bounded.

## [2026.5.9] - 2026-05-09

### Added

- Added an Explore screen for trying chord roots, qualities, extensions, and
  bass notes with a normalized keyboard view and live harmonic context.
- Added a Play button to Explore so you can hear the current chord without a
  MIDI device.

### Changed

- Made highlighted piano keys use stronger theme-based fills and outlines so
  active white and black notes are easier to distinguish.
- Made Help & Support open in-app first, with chord-card Analysis Details
  guidance before linking to GitHub or email support.
- Made the main identity card open Explore directly, including when idle or
  playing a single note or interval, while moving Analysis Details to long
  press.

### Fixed

- Fixed accidental labels in key, note, and Explore controls so sharps and flats
  use musical symbols consistently in the UI.
- Fixed the idle blackout screen so iOS status bar icons stay visible when the
  app is using the light theme.

### Removed

- Removed `5` chord naming for open fifth dyads so piano analysis no longer
  labels incomplete two-note patterns as power chords.

## [2026.3.10] - 2026-03-10

### Changed

- Extended the pressed-key highlight gradient farther down the piano keys so
  active notes read more clearly at a glance.

### Fixed

- Fixed MIDI reconnect after the app has been backgrounded for a longer period
  by forcing a full reconnect when the previous plugin connection state may be
  stale.

## [2026.2.26] - 2026-02-26

### Added

- Added an optional piano keyboard overlay that marks notes in the selected key
  signature with subtle diatonic note markers.

### Changed

- Improved piano key rendering with stronger depth and clearer contrast,
  including a top-edge shadow gradient and refined pressed-key highlights.
- Shortened scale degree tooltip and semantics wording for a more concise,
  consistent in-app explanation.

### Fixed

- Fixed Reset to Defaults so it fully exits Demo Mode and does not restore stale
  demo snapshot theme or key settings during reset.
- Fixed MIDI coach mark onboarding so opening MIDI Settings marks the coach mark
  as seen, preventing it from reappearing on Home after a settings reset when
  users entered through the MIDI flow.
- Fixed scale degree accessibility announcements to use clearer spoken degree
  wording and include the current key name.

## [2026.2.22] - 2026-02-22

### Added

- Added Demo Mode in Settings so you can explore guided chord examples without
  connecting a MIDI device.
- Added a first-launch MIDI coach mark that highlights where to connect and how
  to get started.
- Added mode-aware scale degree numerals (major and natural minor) with
  contextual tooltips that explain each degree's function.

### Changed

- Improved inline onboarding prompts so next-step guidance is clearer during
  setup and connection.
- Key signature selection now persists between app launches.
- Refined copy and spacing across the app for a clearer, more consistent
  experience.
- Upgraded Flutter to `3.41.2` (Dart `3.11.0`) with refreshed locked
  dependencies.

### Fixed

- Fixed Reset to Defaults during active MIDI reconnect attempts so retries are
  canceled immediately and connection status returns to Not connected.

## [2026.2.18] - 2026-02-18

### Added

- Added explicit support for wired USB MIDI connections, with transport-aware
  connection flows in MIDI settings and device selection.
- Added Audio Monitor in Input settings so you can hear incoming MIDI notes with
  built-in SoundFont playback, plus persisted enable/disable and precise volume
  control.
- Added chord degree display in Analysis Details relative to the detected root.

### Changed

- Updated MIDI wording and status indicators to more clearly reflect Bluetooth,
  USB, and network transports.
- Refined sheets and pickers across analysis and MIDI flows with more consistent
  headers, insets, spacing, and divider treatment, including landscape behavior.
- Stabilized persisted settings mappings for theme and chord notation values.

### Fixed

- Fixed wired and other non-Bluetooth manual MIDI connection flows so they no
  longer require Bluetooth permission.
- Fixed MIDI transport mapping so plugin `native` devices are labeled and shown
  as USB transport in app UI.
- Fixed reconnect behavior when forgetting the last device so active retries are
  canceled immediately and status returns cleanly to Not connected.
- Fixed MIDI note-state handling for `All Notes Off` (CC 123) and sustain-safe
  restrike behavior.

## [2026.2.15] - 2026-02-15

### Changed

- Improved accessibility across the app with clearer VoiceOver/TalkBack
  announcements for identity states, MIDI status, and key selection, plus better
  semantic headers and action hints in sheets and modals.
- Increased tap targets across home and MIDI controls, and improved reduced
  motion support by skipping auto-scroll transitions and idle pulse animations
  when animations are disabled.
- Added size-class-aware layouts on larger screens, including a larger identity
  card and improved typography/spacing for near-tie candidates and input
  note/pedal controls.
- Updated portrait tablet keyboard scaling to show more visible keys as screen
  width increases, while preserving a minimum white-key width for readability.
- Updated key signature and analysis details to use adaptive right-side sheets
  on larger layouts with consistent styling, unified headers, and
  swipe-to-dismiss.
- Refined key signature picker wording and layout with a persistent "Key
  Signature" title, a clearer "Accidentals" column label, and better spacing and
  height behavior.
- Updated the Settings color palette picker to adapt by size class, keep the
  picker open for live preview, and improve accessibility with clearer
  selected-state semantics and explicit hints.
- Improved MIDI reconnect reliability on iOS with operation timeouts, and
  post-reconnect confirmation.
- Upgraded Flutter to `3.41.1` (Dart `3.11.0`) with refreshed locked
  dependencies.
- Migrated iOS lifecycle wiring to Apple's `UIScene` model
  (`FlutterSceneDelegate`) to stay aligned with UIKit requirements.

### Fixed

- Fixed settings pages in landscape orientation so list content now respects
  device safe-area insets and avoids camera cutout occlusion.
- Fixed MIDI device picker filtering/deduplication to keep Bluetooth devices
  visible when transport labels vary by platform and collapse duplicate rows
  where the same device appears with a trailing "Bluetooth"/"BLE" name suffix.
- Fixed a last-connected-device state bug where forgetting a device and then
  reconnecting it could leave the card showing a disabled "Reconnect" action
  instead of "Disconnect".
- Fixed `MidiConnectionState.copyWith` so nullable fields can be explicitly
  cleared, preventing stale reconnect messages, retry delays, and Bluetooth
  unavailability details from leaking across connection phases.
- Fixed reconnect edge cases that could leave MIDI stuck on "Connecting..." or
  "Reconnecting..." after app resume or canceled attempts by enforcing strict
  single-flight reconnect ownership and post-await cancellation checks so
  canceled attempts stop cleanly without extra retry UI states.

## [2026.2.12] - 2026-02-12

### Changed

- Refined the home app bar for large text sizes by replacing the MIDI status
  pill with a compact status icon button and clamping title scaling to the
  toolbar height to prevent overflow.
- Smoothed large-text rendering across the home screen with updated input
  display sizing, identity card spacing, tonality bar text scaling, and
  scroll-fade affordances to reduce clipping and make off-screen content
  clearer.
- Let the near-tie chord candidates list grow taller in portrait layouts and
  added a landscape overflow scrollbar to better handle large text sizes.

## [2026.2.4] - 2026-02-04

This release marks the first general availability (GA) release of WhatChord on
the Apple App Store. Google Play distribution remains in closed testing while
tester requirements are completed.

### Added

- Added a **Support** link in _Settings > About_ for reporting issues or
  contacting support directly.

### Changed

- Significantly improved **piano keyboard auto-scroll behavior** to keep
  sounding notes visible in a more stable, intentional, and predictable way.
- Chevron edge indicators now **animate in and out smoothly** and are
  temporarily disabled during automatic scrolling to reduce visual noise.
- Tapping a chevron will **center all currently sounding notes** when they fit
  within the visible keyboard viewport.
- Refactored the **Analysis Details** view into a dedicated modal sheet with
  pinned action buttons and improved content scrolling.
- Improved **MIDI auto-reconnect behavior** by gating startup and resume
  attempts on actual Bluetooth readiness rather than fixed delays.
- Improved auto-reconnect reliability on iOS by handling **MIDI devices that
  change identifiers** between sessions.

### Fixed

- Fixed cases where piano edge chevrons appeared even though no sounding notes
  were actually off-screen.
- Fixed chevrons occasionally pointing to the wrong notes or failing to reveal
  hidden notes when tapped.
- Fixed unexpected piano auto-scroll "jumps" after manual dragging.
- Fixed inconsistent piano scroll positioning when rotating the device or
  changing the visible key count.
- Fixed an auto-reconnect deadlock where the app could remain stuck in
  **"Reconnecting…"** after resuming due to a canceled backoff delay never
  completing.
- Fixed a leaked MIDI connection listener on the home screen that could cause
  duplicate events or unnecessary resource usage during navigation.

## [2026.1.31] - 2026-01-31

### Changed

- Updated edge-to-edge layout behavior to improve landscape rendering, including
  full-bleed backgrounds, cutout-safe content insets, and more compact app bar
  and tonality bar spacing.
- Prepared the iOS build for App Store submission, including updated Xcode build
  settings and export compliance declarations.
- Replaced the unused "Copy as JSON" action in the analysis details sheet with a
  "Report Issue" link to GitHub.
- Improved internal demo mode tooling, including more reliable state isolation,
  deterministic presentation steps, and cleaner entry/exit behavior for testing
  and screenshots.
- Centralized external URL launching logic in a shared core helper.
- Updated Flutter to v3.38.9, aligned the Dart SDK with the bundled Flutter
  release, and upgraded project dependencies.

### Fixed

- Stabilized MIDI connection state propagation (status pill updates, manual
  reconnect UX, scan lifecycle, and transient empty snapshot handling).

## [2026.1.27] - 2026-01-27

This release marks the first Google Play Store submission for closed testing and
includes several refinements to support testing, diagnostics, and store
compliance. It was also submitted to the Apple App Store and subsequently
approved for public availability.

### Added

- Document a Privacy Policy for app store requirements.
- Add an in-app link to the Privacy Policy from the Settings page.
- Display the app version in Analysis Details to help with accurate bug reports
  when sharing diagnostic output.

### Changed

- Align demo chords with those used in app store screenshots.
- Sustain pedal UI now latches manual pedal toggles while a MIDI sustain pedal
  is held down.

### Fixed

- Fix stale Bluetooth MIDI "Connected" state after returning to the foreground
  by reconciling transport state on app resume.
- Reduce MIDI connection notifications to a single confirmation when a device
  successfully connects.

## [2026.1.23] - 2026-01-23

### Added

- Initial support for running WhatChord on iOS, including required platform
  permissions and launch screen assets.
- Re-architected BLE MIDI connectivity around Riverpod state management for
  improved stability and clarity.
- Improved detection and handling of Bluetooth disconnects, permissions, and
  adapter state changes.
- Switched the project to Calendar Versioning (CalVer) for clearer, date-based
  releases.
- Fully automated release publishing using GitHub Actions.
- Adoption of standardized Toolbox Envy scripts for versioning, changelog
  updates, and release tasks.

### Changed

- Identity card details are now opened with a single tap (previously
  long-press).

## [0.8.0] - 2026-01-16

This is a pre-1.0 release intended as a stable public preview.

### Added

- Initial public release of WhatChord.
- Real-time chord analysis engine with musically informed ranking.
- Context-aware enharmonic note spelling.
- Support for Bluetooth MIDI keyboards.
- Clear chord identity display with ambiguity handling.
- Signed Android APK distribution via GitHub Releases.

[Unreleased]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.7.20...HEAD
[2026.7.20]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.7.11...v2026.7.20
[2026.7.11]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.7.6...v2026.7.11
[2026.7.6]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.6.28...v2026.7.6
[2026.6.28]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.6.19...v2026.6.28
[2026.6.19]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.6.14...v2026.6.19
[2026.6.14]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.6.10...v2026.6.14
[2026.6.10]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.6.6...v2026.6.10
[2026.6.6]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.6.1...v2026.6.6
[2026.6.1]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.5.28...v2026.6.1
[2026.5.28]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.5.23...v2026.5.28
[2026.5.23]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.5.21...v2026.5.23
[2026.5.21]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.5.16...v2026.5.21
[2026.5.16]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.5.13...v2026.5.16
[2026.5.13]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.5.9...v2026.5.13
[2026.5.9]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.3.10...v2026.5.9
[2026.3.10]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.2.26...v2026.3.10
[2026.2.26]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.2.22...v2026.2.26
[2026.2.22]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.2.18...v2026.2.22
[2026.2.18]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.2.15...v2026.2.18
[2026.2.15]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.2.12...v2026.2.15
[2026.2.12]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.2.4...v2026.2.12
[2026.2.4]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.1.31...v2026.2.4
[2026.1.31]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.1.27...v2026.1.31
[2026.1.27]:
  https://github.com/EarthmanMuons/whatchord/compare/v2026.1.23...v2026.1.27
[2026.1.23]:
  https://github.com/EarthmanMuons/whatchord/compare/v0.8.0...v2026.1.23
[0.8.0]: https://github.com/EarthmanMuons/whatchord/commits/v0.8.0
