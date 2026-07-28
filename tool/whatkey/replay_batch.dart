// Replays recorded sounding-set streams through the real Phase 1 capture
// path for WhatKey fixture generation (research/whatkey/).
//
// Reads JSON-lines requests on stdin, one piece per line:
//   {"id": "...", "context": "C:maj", "segmenterMinMs": 200,
//    "snapshots": [{"timestampMs": 0, "midiNotes": [60, 64, 67]}, ...]}
// where each snapshot is the pedal-aware sounding set after a change, and
// writes one JSON line per piece with the committed ChordEvents in the
// fixture event schema (without labels; the caller attaches those).
// segmenterMinMs is optional (default 200, the app's live value); it exists
// for the stacked-filter experiments, and any adopted change must ship in
// the app's segmenter default too.
//
// This is the same pipeline the app runs live: the analyzer with voicing
// evidence, capture gating at fewer than three notes, and the actual
// ChordEventSegmenter (pending-challenger debounce, minimum duration), so
// fixtures built here reflect real capture behavior on performed input,
// finger rolls and pedal blur included.
//
// Two optional fields serve the performed-input attribution arms
// (research/performed-input/PROTOCOL.md):
//   "contextTimeline": [{"timestampMs": 0, "context": "F:min"}, ...]
//     switches the analysis context at the given times (arm B: annotated
//     analyst key as context) instead of the fixed "context" value.
//   "spanBoundaries": [ms, ...] with "spanNoteThreshold": 0.25
//     replaces the segmenter with annotation-boundary segmentation (arm C):
//     each adjacent boundary pair is one span, whose voicing is the notes
//     sounding at least the threshold fraction of the span, still subject
//     to the capture gate (fewer than three notes -> no event).
//   "pedalDemotion": "transient" | "attack"
//     pedal-blur prototype (performed-input log 2026-07-27-10). Requires
//     snapshots with a "held" list (provenance extraction). Sustained-only
//     notes are dropped from the analyzed voicing when their key press was
//     shorter than transientMs ("transient"), or additionally once any
//     fresh attack lands after their release ("attack").
//   "liveKeyHalfLifeSeconds": 30 | 4 | 1
//     arm A1: the shipped HMM key detector runs in the loop with the given
//     evidence half-life (the stable/balanced/reactive presets). Analysis
//     starts from the fixed "context" and follows the detector's claimed
//     key forward (sticky across abstentions), mirroring the app's live
//     feedback of inferred key into analysis context. Mutually exclusive
//     with contextTimeline and spanBoundaries.
//   "emitFrames": true
//     prefix-stability measurement (performed-input avenue 2): the output
//     additionally carries "frames", the per-snapshot display-label change
//     points. An entry {timestampMs, rootPc, quality} marks the top-1
//     label changing to that identity; {timestampMs} alone marks the
//     display going blank (fewer than three notes or no candidates).
//     Segmenter path only.

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';
import 'package:whatkey/whatkey.dart' show HmmKeyDetector;

import '../src/chord_id_engine.dart';

final _analyzers = <ChordAnalysisProfile, ChordAnalyzer>{
  for (final profile in ChordAnalysisProfile.values)
    profile: ChordAnalyzer(analysisProfile: profile),
};

// Every caller must declare the chord-ranking policy: a silent default would
// let a fixture set inherit the wrong profile when a request omits the field.
String _requireProfile(Map<String, dynamic> request) {
  final profile = request['analysisProfile'] as String?;
  if (profile == null) {
    throw ArgumentError(
      'Request is missing required "analysisProfile" '
      '(one of ${ChordAnalysisProfile.values.map((p) => p.name).join(', ')})',
    );
  }
  return profile;
}

void main() {
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;

    final request = jsonDecode(line) as Map<String, dynamic>;
    final profile = ChordAnalysisProfile.values.byName(
      _requireProfile(request),
    );
    final contexts = _ContextTimeline(
      request['context'] as String,
      (request['contextTimeline'] as List?)?.cast<Map>(),
    );
    var snapshots = [
      for (final raw in (request['snapshots'] as List).cast<Map>())
        (
          timestampMs: raw['timestampMs'] as int,
          midiNotes: (raw['midiNotes'] as List).cast<int>()..sort(),
          held: (raw['held'] as List?)?.cast<int>(),
        ),
    ];
    final demotion = request['pedalDemotion'] as String?;
    if (demotion != null) {
      snapshots = _demotePedalTones(snapshots, demotion);
    }
    final boundaries = (request['spanBoundaries'] as List?)?.cast<int>();
    final liveKeySeconds = request['liveKeyHalfLifeSeconds'] as int?;
    if (liveKeySeconds != null &&
        (boundaries != null || request['contextTimeline'] != null)) {
      throw ArgumentError(
        'liveKeyHalfLifeSeconds is mutually exclusive with '
        'spanBoundaries and contextTimeline',
      );
    }

    final frames = (request['emitFrames'] as bool?) ?? false
        ? <Map<String, Object?>>[]
        : null;
    final eventsJson = boundaries != null
        ? _spanEvents(
            snapshots,
            boundaries,
            (request['spanNoteThreshold'] as num?)?.toDouble() ?? 0.25,
            contexts,
            profile,
          )
        : _segmenterEvents(
            snapshots,
            (request['segmenterMinMs'] as int?) ?? 200,
            contexts,
            profile,
            liveKey: liveKeySeconds == null
                ? null
                : HmmKeyDetector(
                    decayHalfLife: Duration(seconds: liveKeySeconds),
                  ),
            frames: frames,
          );

    stdout.writeln(
      jsonEncode(<String, Object?>{
        'id': request['id'],
        'events': eventsJson,
        'frames': ?frames,
      }),
    );
  });
}

typedef _Snapshot = ({int timestampMs, List<int> midiNotes, List<int>? held});

const _transientPressMs = 200;

/// Pedal-blur demotion prototype: rewrites each snapshot's voicing so that
/// sustained-only notes (in midiNotes but not held) are dropped when their
/// press was shorter than [_transientPressMs], and under the "attack" rule
/// additionally once any fresh attack lands after their release. Physically
/// held notes always pass through.
List<_Snapshot> _demotePedalTones(List<_Snapshot> snapshots, String rule) {
  final heldSince = <int, int>{};
  final releasedAt = <int, int>{};
  final pressMs = <int, int>{};
  var lastAttackMs = -1;
  var previousHeld = const <int>{};
  final rewritten = <_Snapshot>[];
  for (final snapshot in snapshots) {
    final held = (snapshot.held ?? const <int>[]).toSet();
    final now = snapshot.timestampMs;
    for (final note in held) {
      if (!previousHeld.contains(note)) {
        heldSince[note] = now;
        releasedAt.remove(note);
        pressMs.remove(note);
        lastAttackMs = now;
      }
    }
    final sounding = snapshot.midiNotes.toSet();
    for (final note in previousHeld) {
      if (!held.contains(note) && sounding.contains(note)) {
        releasedAt[note] = now;
        pressMs[note] = now - (heldSince[note] ?? now);
      }
    }
    heldSince.removeWhere((note, _) => !sounding.contains(note));
    releasedAt.removeWhere((note, _) => !sounding.contains(note));
    pressMs.removeWhere((note, _) => !sounding.contains(note));
    previousHeld = held;

    final voicing = [
      for (final note in snapshot.midiNotes)
        if (held.contains(note) ||
            !_demoted(note, rule, releasedAt, pressMs, lastAttackMs))
          note,
    ];
    rewritten.add((timestampMs: now, midiNotes: voicing, held: snapshot.held));
  }
  return rewritten;
}

bool _demoted(
  int note,
  String rule,
  Map<int, int> releasedAt,
  Map<int, int> pressMs,
  int lastAttackMs,
) {
  final released = releasedAt[note];
  if (released == null) return false;
  if ((pressMs[note] ?? _transientPressMs) < _transientPressMs) return true;
  if (rule == 'attack' && lastAttackMs > released) return true;
  return false;
}

/// The analysis context active at a timestamp: the fixed request context, or
/// the latest contextTimeline entry at or before the timestamp (arm B).
class _ContextTimeline {
  _ContextTimeline(String fixed, List<Map>? timeline)
    : _switches = [
        (timestampMs: 0, context: _build(fixed)),
        if (timeline != null)
          for (final entry in timeline)
            (
              timestampMs: entry['timestampMs'] as int,
              context: _build(entry['context'] as String),
            ),
      ];

  final List<({int timestampMs, AnalysisContext context})> _switches;
  var _at = 0;

  static final _cache = <String, AnalysisContext>{};

  static AnalysisContext _build(String wire) =>
      _cache.putIfAbsent(wire, () => forTonality(parseTonality(wire)));

  static AnalysisContext forTonality(Tonality tonality) {
    final keySignature = KeySignature.fromTonality(tonality);
    return AnalysisContext(
      tonality: tonality,
      keySignature: keySignature,
      spellingPolicy: NoteSpellingPolicy(
        preferFlats: keySignature.prefersFlats,
      ),
    );
  }

  AnalysisContext at(int timestampMs) {
    while (_at + 1 < _switches.length &&
        _switches[_at + 1].timestampMs <= timestampMs) {
      _at++;
    }
    while (_at > 0 && _switches[_at].timestampMs > timestampMs) {
      _at--;
    }
    return _switches[_at].context;
  }
}

List<Map<String, Object?>> _segmenterEvents(
  List<_Snapshot> snapshots,
  int segmenterMinMs,
  _ContextTimeline contexts,
  ChordAnalysisProfile profile, {
  HmmKeyDetector? liveKey,
  List<Map<String, Object?>>? frames,
}) {
  final segmenter = ChordEventSegmenter(
    minChordDuration: Duration(milliseconds: segmenterMinMs),
  );
  final events = <ChordEvent>[];
  var liveContext = liveKey == null ? null : contexts.at(0);
  var lastMs = 0;
  (int, String)? displayed;

  void commit(Iterable<ChordEvent> committed) {
    for (final event in committed) {
      events.add(event);
      if (liveKey == null) continue;
      final claim = liveKey.onEvent(event).claim;
      if (claim != null) {
        liveContext = _ContextTimeline.forTonality(claim.tonality);
      }
    }
  }

  for (final snapshot in snapshots) {
    lastMs = snapshot.timestampMs;
    final now = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final frame = _frame(
      snapshot.midiNotes,
      liveContext ?? contexts.at(lastMs),
      profile,
    );
    if (frames != null) {
      final identity = frame?.candidates.first.identity;
      final label = identity == null
          ? null
          : (identity.rootPc, identity.quality.name);
      if (label != displayed) {
        frames.add({
          'timestampMs': lastMs,
          if (label != null) 'rootPc': label.$1,
          if (label != null) 'quality': label.$2,
        });
        displayed = label;
      }
    }
    commit(segmenter.onFrame(frame, now));
  }
  commit(segmenter.flush(DateTime.fromMillisecondsSinceEpoch(lastMs + 1)));
  return [
    for (var index = 0; index < events.length; index++)
      _eventJson(index, events[index]),
  ];
}

/// Annotation-boundary segmentation (arm C): one candidate voicing per span,
/// built from the notes sounding at least [threshold] of the span duration.
List<Map<String, Object?>> _spanEvents(
  List<_Snapshot> snapshots,
  List<int> boundaries,
  double threshold,
  _ContextTimeline contexts,
  ChordAnalysisProfile profile,
) {
  final eventsJson = <Map<String, Object?>>[];
  var cursor = 0;
  for (var span = 0; span + 1 < boundaries.length; span++) {
    final spanStart = boundaries[span];
    final spanEnd = boundaries[span + 1];
    if (spanEnd <= spanStart) continue;

    while (cursor + 1 < snapshots.length &&
        snapshots[cursor + 1].timestampMs <= spanStart) {
      cursor++;
    }
    final soundedMs = <int, int>{};
    for (var index = cursor; index < snapshots.length; index++) {
      final start = snapshots[index].timestampMs;
      if (start >= spanEnd) break;
      final end = index + 1 < snapshots.length
          ? snapshots[index + 1].timestampMs
          : spanEnd;
      final overlap =
          (end < spanEnd ? end : spanEnd) -
          (start > spanStart ? start : spanStart);
      if (overlap <= 0) continue;
      for (final note in snapshots[index].midiNotes) {
        soundedMs[note] = (soundedMs[note] ?? 0) + overlap;
      }
    }

    final minMs = threshold * (spanEnd - spanStart);
    final voicing = [
      for (final entry in soundedMs.entries)
        if (entry.value >= minMs) entry.key,
    ]..sort();
    final frame = _frame(voicing, contexts.at(spanStart), profile);
    if (frame == null) continue;
    eventsJson.add({
      'index': eventsJson.length,
      'timestampMs': spanStart,
      'durationMs': spanEnd - spanStart,
      'midiNotes': voicing,
      'pcMask': frame.input.pcMask,
      'bassPc': frame.input.bassPc,
      'noteCount': frame.input.noteCount,
      'candidates': _candidatesJson(frame.candidates),
    });
  }
  return eventsJson;
}

/// Mirrors `_captureFrameProvider`: null below three sounding notes, else the
/// analyzed chord with its surfaced near-tie alternatives.
CaptureFrame? _frame(
  List<int> midiNotes,
  AnalysisContext context,
  ChordAnalysisProfile profile,
) {
  if (midiNotes.length < 3) return null;

  var pcMask = 0;
  for (final note in midiNotes) {
    pcMask |= 1 << (note % 12);
  }
  final input = ChordInput(
    pcMask: pcMask,
    bassPc: midiNotes.first % 12,
    noteCount: midiNotes.length,
  );
  final voicing = ObservedVoicing.fromMidi(midiNotes);
  final ranked = _analyzers[profile]!.analyze(
    input,
    context: context,
    voicing: voicing,
  );
  if (ranked.isEmpty) return null;

  return CaptureFrame(
    input: input,
    voicing: voicing,
    candidates: [ranked.first, ...ChordCandidateRanking.alternatives(ranked)],
    tonality: context.tonality,
  );
}

Map<String, Object?> _eventJson(int index, ChordEvent event) => {
  'index': index,
  'timestampMs': event.timestamp.millisecondsSinceEpoch,
  'durationMs': event.duration.inMilliseconds,
  'midiNotes': event.voicing.midiNotes,
  'pcMask': event.input.pcMask,
  'bassPc': event.input.bassPc,
  'noteCount': event.input.noteCount,
  'candidates': _candidatesJson(event.candidates),
};

List<Map<String, Object?>> _candidatesJson(List<ChordCandidate> candidates) => [
  for (final candidate in candidates)
    <String, Object?>{
      'rootPc': candidate.identity.rootPc,
      'bassPc': candidate.identity.bassPc,
      'quality': candidate.identity.quality.name,
      'extensions': [
        for (final extension in candidate.identity.extensions) extension.name,
      ],
      'presentIntervalsMask': candidate.identity.presentIntervalsMask,
      'cost': candidate.cost,
    },
];
