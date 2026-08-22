// Persistent product-path analyzer for the final POP909 held exposure.
//
// The Python harness owns corpus parsing and provenance. This process receives
// label-blind normalized event streams and executes the exact pure-Dart product
// engine used by the app, including primary availability and display timers.

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';

final _analyzer = ChordAnalyzer(analysisProfile: ChordAnalysisProfile.current);
final _defaultContext = _analysisContext(
  const Tonality(Tonic.c, TonalityMode.major),
  PlayingContext.solo,
);
final _contextAuditEntries = _buildContextAuditEntries();

void main() {
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;
    try {
      final request = jsonDecode(line) as Map<String, dynamic>;
      stdout.writeln(jsonEncode(_analyze(request)));
    } catch (error, stackTrace) {
      stderr.writeln(error);
      stderr.writeln(stackTrace);
      exit(1);
    }
  });
}

Map<String, Object?> _analyze(Map<String, dynamic> request) {
  final id = request['id'] as String;
  final endTimestampMs = request['endTimestampMs'] as int;
  final events = (request['events'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final frames = (request['frames'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  if (events.length != frames.length) {
    throw ArgumentError('events and frames must have equal length');
  }

  final engine = PolychordProductEngine(initialPrimaryDisplayable: false);
  final recorder = _Recorder();
  ChordCandidate? currentPrimary;
  var previousTimestampMs = 0;

  for (var index = 0; index < events.length; index++) {
    final event = events[index];
    final expectedFrame = frames[index];
    final timestampMs = event['timestampMs'] as int;
    if (timestampMs < previousTimestampMs || timestampMs > endTimestampMs) {
      throw ArgumentError('source event timestamps are invalid');
    }

    final deadlineMs = engine.latestObservation?.display.deadlineMs;
    if (deadlineMs != null && deadlineMs <= timestampMs) {
      recorder.record(
        trigger: 'timer',
        sourceEventIndex: index - 1,
        observation: engine.observeTimer(deadlineMs),
        primary: currentPrimary,
      );
    }

    final observation = switch (event['type']) {
      'noteOn' => engine.observeEvent(
        PolychordNoteOnEvent(
          timestampMs: timestampMs,
          midiNote: event['midiNote'] as int,
          velocity: event['velocity'] as int,
        ),
      ),
      'noteOff' => engine.observeEvent(
        PolychordNoteOffEvent(
          timestampMs: timestampMs,
          midiNote: event['midiNote'] as int,
          velocity: event['velocity'] as int,
        ),
      ),
      'pedal' => engine.observeEvent(
        PolychordSustainPedalEvent(
          timestampMs: timestampMs,
          down: event['down'] as bool,
        ),
      ),
      'allNotesOff' => engine.reset(
        timestampMs: timestampMs,
        initiallyPedalDown: expectedFrame['pedalDown'] as bool,
      ),
      final type => throw FormatException('unsupported event type: $type'),
    };
    _validateFrame(observation.frame, expectedFrame, event['type'] as String);
    currentPrimary = _analyzePrimary(
      (expectedFrame['soundingMidiNotes'] as List<dynamic>).cast<int>(),
      _defaultContext,
    );
    recorder.record(
      trigger: 'source-event',
      sourceEventIndex: index,
      observation: observation,
      primary: currentPrimary,
      sourceFrame: true,
    );

    if (observation.frame != null &&
        engine.primaryDisplayable != (currentPrimary != null)) {
      recorder.record(
        trigger: 'primary-availability',
        sourceEventIndex: index,
        observation: engine.setPrimaryDisplayable(
          timestampMs: timestampMs,
          displayable: currentPrimary != null,
        ),
        primary: currentPrimary,
      );
    }
    previousTimestampMs = timestampMs;
  }

  final deadlineMs = engine.latestObservation?.display.deadlineMs;
  if (deadlineMs != null && deadlineMs <= endTimestampMs) {
    recorder.record(
      trigger: 'timer',
      sourceEventIndex: events.length - 1,
      observation: engine.observeTimer(deadlineMs),
      primary: currentPrimary,
    );
  }
  recorder.record(
    trigger: 'midi-end',
    sourceEventIndex: events.length - 1,
    observation: engine.reset(timestampMs: endTimestampMs),
    primary: null,
  );

  return <String, Object?>{
    'schema': 'polychord-held-exposure-piece/1',
    'id': id,
    'endTimestampMs': endTimestampMs,
    'sourceEventCount': events.length,
    ...recorder.finish(),
  };
}

void _validateFrame(
  PolychordOnsetTrackingFrame? actual,
  Map<String, dynamic> expected,
  String eventType,
) {
  final expectedPressed = (expected['pressedMidiNotes'] as List<dynamic>)
      .cast<int>();
  final expectedSustained = (expected['sustainedMidiNotes'] as List<dynamic>)
      .cast<int>();
  final expectedSounding = (expected['soundingMidiNotes'] as List<dynamic>)
      .cast<int>();
  final expectedPedal = expected['pedalDown'] as bool;
  if (eventType == 'allNotesOff') {
    if (actual != null ||
        expectedPressed.isNotEmpty ||
        expectedSustained.isNotEmpty ||
        expectedSounding.isNotEmpty) {
      throw StateError('all-notes-off reset diverges from normalized state');
    }
    return;
  }
  if (actual == null ||
      !_listsEqual(actual.pressedMidiNotes, expectedPressed) ||
      !_listsEqual(actual.sustainedMidiNotes, expectedSustained) ||
      !_listsEqual(actual.soundingMidiNotes, expectedSounding) ||
      actual.pedalDown != expectedPedal) {
    throw StateError('product tracker diverges from normalized source frame');
  }
}

bool _listsEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

final class _Recorder {
  final List<Map<String, Object?>> diagnosticActions = [];
  final List<Map<String, Object?>> episodes = [];
  final Map<String, int> counts = {};
  Map<String, Object?>? _openEpisode;

  void record({
    required String trigger,
    required int sourceEventIndex,
    required PolychordProductObservation observation,
    required ChordCandidate? primary,
    bool sourceFrame = false,
  }) {
    final transition = observation.display.transition.name;
    _increment('actions');
    _increment('transition:$transition');
    if (sourceFrame) {
      _increment('sourceFrames');
      _add('candidateInstances', observation.candidates.length);
      if (observation.candidates.isNotEmpty) _increment('candidateFrames');
      if (observation.rawDecision?.selected != null) {
        _increment('rawSelectedFrames');
      }
      final selectorReason = observation.rawDecision?.reasonCode;
      if (selectorReason != null) {
        _increment('selectorReason:$selectorReason');
      }
      if (observation.authorization?.key != null) {
        _increment('authorizedFrames');
      }
      final authorizationReason = observation.authorization?.reasonCode;
      if (authorizationReason != null) {
        _increment('authorizationReason:$authorizationReason');
      }
    }

    final primaryJson = _primaryJson(primary, _defaultContext);
    final retainDiagnostic =
        observation.candidates.isNotEmpty ||
        observation.rawDecision?.selected != null ||
        observation.authorization?.key != null ||
        observation.display.state != PolychordProductDisplayState.absent ||
        observation.display.transition !=
            PolychordProductDisplayTransition.none;
    if (retainDiagnostic) {
      diagnosticActions.add({
        'diagnosticActionIndex': diagnosticActions.length,
        'trigger': trigger,
        'sourceEventIndex': sourceEventIndex,
        'primary': primaryJson,
        'observation': observation.toJson(),
      });
    }

    if (transition == 'appearance') {
      if (_openEpisode != null) {
        throw StateError('appearance occurred while an episode was open');
      }
      final frame = observation.frame!;
      final audit = _auditPrimaryContexts(frame.soundingMidiNotes);
      if (audit['availabilityInvariant'] != true) {
        throw StateError('displayed primary availability varies by context');
      }
      _openEpisode = {
        'episodeIndex': episodes.length,
        'startMs': observation.observationTimestampMs,
        'startTrigger': trigger,
        'sourceStartEventIndex': sourceEventIndex,
        'selected': observation.display.key!.candidate.toJson(),
        'soundingMidiNotes': frame.soundingMidiNotes,
        'pressedMidiNotes': frame.pressedMidiNotes,
        'sustainedMidiNotes': frame.sustainedMidiNotes,
        'pedalDown': frame.pedalDown,
        'primary': primaryJson,
        'primaryContextAudit': audit,
      };
    } else if (transition == 'clear') {
      _closeEpisode(
        timestampMs: observation.observationTimestampMs,
        trigger: trigger,
        sourceEventIndex: sourceEventIndex,
        reasonCode: observation.display.reasonCode,
      );
    }
  }

  Map<String, Object?> finish() {
    if (_openEpisode != null) {
      throw StateError('held exposure ended with an open display episode');
    }
    return {
      'counts': {
        for (final key in counts.keys.toList()..sort()) key: counts[key],
      },
      'displayedMs': episodes.fold<int>(
        0,
        (total, episode) => total + (episode['durationMs']! as int),
      ),
      'stableEpisodes': episodes,
      'diagnosticActions': diagnosticActions,
    };
  }

  void _closeEpisode({
    required int timestampMs,
    required String trigger,
    required int sourceEventIndex,
    required String? reasonCode,
  }) {
    final episode = _openEpisode;
    if (episode == null) return;
    final startMs = episode['startMs']! as int;
    episodes.add({
      ...episode,
      'endMs': timestampMs,
      'durationMs': timestampMs - startMs,
      'endTrigger': trigger,
      'sourceEndEventIndex': sourceEventIndex,
      'endReasonCode': reasonCode,
    });
    _openEpisode = null;
  }

  void _increment(String key) => counts[key] = (counts[key] ?? 0) + 1;

  void _add(String key, int value) => counts[key] = (counts[key] ?? 0) + value;
}

ChordCandidate? _analyzePrimary(List<int> midiNotes, AnalysisContext context) {
  if (midiNotes.length < 3) return null;
  var pcMask = 0;
  for (final note in midiNotes) {
    pcMask |= 1 << (note % 12);
  }
  final ranked = _analyzer.analyze(
    ChordInput(
      pcMask: pcMask,
      bassPc: midiNotes.first % 12,
      noteCount: midiNotes.length,
    ),
    context: context,
    voicing: ObservedVoicing.fromMidi(midiNotes),
  );
  return ranked.isEmpty ? null : ranked.first;
}

Map<String, Object?> _auditPrimaryContexts(List<int> midiNotes) {
  var displayableCount = 0;
  for (final entry in _contextAuditEntries) {
    if (_analyzePrimary(midiNotes, entry.context) != null) displayableCount++;
  }
  return {
    'contextCount': _contextAuditEntries.length,
    'displayableCount': displayableCount,
    'availabilityInvariant':
        displayableCount == 0 ||
        displayableCount == _contextAuditEntries.length,
  };
}

Map<String, Object?>? _primaryJson(
  ChordCandidate? candidate,
  AnalysisContext context,
) {
  if (candidate == null) return null;
  final presentation = ChordPresentationBuilder.fromIdentity(
    identity: candidate.identity,
    tonality: context.tonality,
    notation: ChordNotationStyle.textual,
  );
  return {
    'rootPc': candidate.identity.rootPc,
    'bassPc': candidate.identity.bassPc,
    'quality': candidate.identity.quality.name,
    'symbol': presentation.symbol.toString(),
    'longLabel': presentation.semanticLabel,
  };
}

AnalysisContext _analysisContext(
  Tonality tonality,
  PlayingContext playingContext,
) {
  final keySignature = KeySignature.fromTonality(tonality);
  return AnalysisContext(
    tonality: tonality,
    keySignature: keySignature,
    spellingPolicy: NoteSpellingPolicy(preferFlats: keySignature.prefersFlats),
    playingContext: playingContext,
  );
}

List<({String id, AnalysisContext context})> _buildContextAuditEntries() {
  const majorTonics = [
    Tonic.c,
    Tonic.dFlat,
    Tonic.d,
    Tonic.eFlat,
    Tonic.e,
    Tonic.f,
    Tonic.fSharp,
    Tonic.g,
    Tonic.aFlat,
    Tonic.a,
    Tonic.bFlat,
    Tonic.b,
  ];
  const minorTonics = [
    Tonic.c,
    Tonic.cSharp,
    Tonic.d,
    Tonic.eFlat,
    Tonic.e,
    Tonic.f,
    Tonic.fSharp,
    Tonic.g,
    Tonic.gSharp,
    Tonic.a,
    Tonic.bFlat,
    Tonic.b,
  ];
  return [
    for (final tonality in [
      for (final tonic in majorTonics) Tonality(tonic, TonalityMode.major),
      for (final tonic in minorTonics) Tonality(tonic, TonalityMode.minor),
    ])
      for (final playingContext in const [
        PlayingContext.solo,
        PlayingContext.ensemble,
      ])
        (
          id:
              '${tonality.tonic.label}:${tonality.mode.name}:'
              '${playingContext.name}',
          context: _analysisContext(tonality, playingContext),
        ),
  ];
}
