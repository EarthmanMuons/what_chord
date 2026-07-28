# 2026-07-28: Display-policy UX brief: the exact change and its decisions

**Goal.** Hand the display-policy frontier (logs -15, 2026-07-28-02) to the
product conversation as a concrete change proposal with its decision points
enumerated, grounded in the app's actual wiring.

**Current wiring.** The identity card derives per sounding change
(`identityDisplayProvider` watching the live candidate providers), softened only
by a 260 ms crossfade. The `ChordEventSegmenter` already runs live in
`ChordHistoryNotifier`, complete with the pending-challenger timer, but its
stability judgment feeds only history and key detection. Display and capture
watch the same frames and disagree about what is real; the card flashes names
history never records.

**Proposed change, minimal shape.**

1. Package: `ChordEventSegmenter` exposes its active chord read-only
   (`CaptureFrame? get active`, `DateTime? get activeSince`). Pure getters, no
   behavior change, no guard implications.
2. App state: `ChordHistoryNotifier` publishes the active frame as a
   displayed-frame provider, updated from `_onFrame` and the pending timer
   (provider write-back rule applies).
3. Presentation: the chord branch of `identityDisplayProvider` reads the
   displayed frame; note and dyad branches stay instant. Analysis details and
   the ranking sheet follow the same frame so all panes agree, and the identity
   card becomes consistent with recent-chords history.

Measured expectation (offline, two idioms): flicker share 0.47 to 0.06
(classical) and 0.19 to 0.08 (pop), switches 5.4/s to 0.7/s, mid-chord late
renames eliminated, zero chords missed, at roughly 200 ms of lag whose true
in-app distribution is the first thing a prototype should measure.

**Decisions to make.**

1. Gap behavior: during unstable 3-plus-note stretches, hold the last stable
   chord (the point of the change); at true release below three notes, recommend
   falling through to note/dyad/blank as today, preserving "the display reflects
   what sounds" at the silence boundary. Alternatives: hold through silence, or
   hold dimmed.
2. Onset rule: show a new chord immediately when nothing is active (matches
   segmenter semantics, cuts perceived latency for the common case) versus only
   after 200 ms survival (what the simulation modeled). The simulator can price
   the immediate-onset variant offline before choosing.
3. Demo and lookup: capture is gated off for both. Recommend a display-only
   segmenter for demo (it showcases the real experience) and raw display for
   lookup (manual entry, no timing dimension).
4. Default versus preference: recommend default-on with no new setting; the raw
   behavior (five changes per second, half of display life under half a second)
   is hard to defend as a preference. Most debatable call.
5. Provisional rendering of the pending challenger (dimmed): recommend not in
   v1.

**Validation plan if pursued.** Prototype measures the true commit-lag
distribution in-app; the offline simulator prices the onset-rule variant;
broader-corpus stability replication is already done (POP909). Accessibility
note: fewer label changes also means saner screen-reader announcements.

**Decisions.** None taken here; this entry is the handoff brief. The
initiative's research surface is complete.
