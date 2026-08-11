// Persistent pure-Dart analyzer for the preregistered polychord development
// exposure. Corpus parsing and provenance remain in development_exposure.py;
// this process receives label-blind observation payloads only.

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';

final _analyzer = ChordAnalyzer(analysisProfile: ChordAnalysisProfile.current);
const _selector = PolychordRegisterSelector();
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
      stdout.writeln(jsonEncode(_analyzeRequest(request)));
    } catch (error, stackTrace) {
      stderr.writeln(error);
      stderr.writeln(stackTrace);
      exit(1);
    }
  });
}

Map<String, Object?> _analyzeRequest(Map<String, dynamic> request) {
  final kind = request['kind'];
  return switch (kind) {
    'eventStream' => _analyzeEventStream(request),
    'committedEvents' => _analyzeCommittedEvents(request),
    _ => throw ArgumentError.value(kind, 'kind', 'unsupported request kind'),
  };
}

Map<String, Object?> _analyzeEventStream(Map<String, dynamic> request) {
  final id = _requiredString(request['id'], 'id');
  final endTimestampMs = _requiredInt(
    request['endTimestampMs'],
    'endTimestampMs',
    minimum: 0,
  );
  final frames = <_Observation>[
    for (final (index, raw) in (request['frames'] as List<dynamic>).indexed)
      _Observation.fromJson(raw as Map<String, dynamic>, 'frames[$index]'),
  ];
  _validateTimeline(frames, endTimestampMs);

  final runtimes = {
    for (final profile in PolychordRegisterSelectorProfile.values)
      profile: _ProfileRuntime(profile),
  };
  final analyzedFrames = <Map<String, Object?>>[];
  final timerTransitions = <Map<String, Object?>>[];

  _Observation? previousObservation;
  ChordCandidate? previousPrimary;
  Map<String, Object?>? previousContextAudit;
  final previousSelections =
      <PolychordRegisterSelectorProfile, PolychordCandidate?>{};
  final previousDecisions =
      <PolychordRegisterSelectorProfile, PolychordRegisterDecision>{};

  for (var index = 0; index < frames.length; index++) {
    final observation = frames[index];
    if (previousObservation != null) {
      for (final profile in PolychordRegisterSelectorProfile.values) {
        final runtime = runtimes[profile]!;
        final deadline = runtime.gate.pendingDeadline;
        if (deadline != null &&
            deadline.inMilliseconds <= observation.timestampMs) {
          final atMs = deadline.inMilliseconds;
          final result = runtime.observe(
            timestampMs: atMs,
            rawSelected: previousSelections[profile],
            primaryDisplayable: previousPrimary != null,
            observation: previousObservation,
            primary: previousPrimary,
            contextAudit: previousContextAudit,
            decision: previousDecisions[profile],
            trigger: 'timer',
          );
          timerTransitions.add({
            'timestampMs': atMs,
            'selectorId': profile.selectorId,
            'sourceAfterEventIndex': previousObservation.afterEventIndex,
            'result': _gateResultJson(result),
          });
        }
      }
    }

    final notes = observation.soundingMidiNotes;
    final primary = _analyzePrimary(notes, _defaultContext);
    final decisions = {
      for (final profile in PolychordRegisterSelectorProfile.values)
        profile: _selector.decide(notes, profile: profile),
    };
    final anySelected = decisions.values.any(
      (decision) => decision.selected != null,
    );
    final contextAudit = anySelected ? _auditPrimaryContexts(notes) : null;
    final nextTimestampMs = index + 1 < frames.length
        ? frames[index + 1].timestampMs
        : endTimestampMs;
    final dwellMs = nextTimestampMs - observation.timestampMs;
    final timestampTerminal =
        index + 1 == frames.length || nextTimestampMs > observation.timestampMs;
    final profileFrames = <String, Object?>{};

    for (final profile in PolychordRegisterSelectorProfile.values) {
      final decision = decisions[profile]!;
      final runtime = runtimes[profile]!;
      final result = runtime.observe(
        timestampMs: observation.timestampMs,
        rawSelected: decision.selected,
        primaryDisplayable: primary != null,
        observation: observation,
        primary: primary,
        contextAudit: contextAudit,
        decision: decision,
        trigger: 'source-event',
      );
      runtime.measureFrame(
        observation: observation,
        decision: decision,
        primaryDisplayable: primary != null,
        dwellMs: dwellMs,
        timestampTerminal: timestampTerminal,
      );
      profileFrames[profile.selectorId] = {
        'decision': decision.toJson(),
        'outerReasonCodes': decision.selected != null && primary == null
            ? const ['primary-not-displayable']
            : const <String>[],
        'gate': _gateResultJson(result),
      };
      previousSelections[profile] = decision.selected;
      previousDecisions[profile] = decision;
    }

    analyzedFrames.add({
      ...observation.toJson(),
      'dwellMs': dwellMs,
      'timestampTerminal': timestampTerminal,
      'primary': _primaryJson(primary, _defaultContext),
      'primaryContextAudit': contextAudit,
      'profiles': profileFrames,
    });
    previousObservation = observation;
    previousPrimary = primary;
    previousContextAudit = contextAudit;
  }

  if (previousObservation != null) {
    for (final profile in PolychordRegisterSelectorProfile.values) {
      final runtime = runtimes[profile]!;
      final deadline = runtime.gate.pendingDeadline;
      if (deadline != null && deadline.inMilliseconds <= endTimestampMs) {
        final atMs = deadline.inMilliseconds;
        final result = runtime.observe(
          timestampMs: atMs,
          rawSelected: previousSelections[profile],
          primaryDisplayable: previousPrimary != null,
          observation: previousObservation,
          primary: previousPrimary,
          contextAudit: previousContextAudit,
          decision: previousDecisions[profile],
          trigger: 'timer',
        );
        timerTransitions.add({
          'timestampMs': atMs,
          'selectorId': profile.selectorId,
          'sourceAfterEventIndex': previousObservation.afterEventIndex,
          'result': _gateResultJson(result),
        });
      }
      final result = runtime.observe(
        timestampMs: endTimestampMs,
        rawSelected: null,
        primaryDisplayable: false,
        observation: previousObservation,
        primary: null,
        contextAudit: null,
        decision: null,
        trigger: 'midi-end',
      );
      timerTransitions.add({
        'timestampMs': endTimestampMs,
        'selectorId': profile.selectorId,
        'sourceAfterEventIndex': previousObservation.afterEventIndex,
        'result': _gateResultJson(result),
      });
    }
  }

  return {
    'schema': 'polychord-development-exposure-dart-piece/1',
    'kind': 'eventStream',
    'id': id,
    'endTimestampMs': endTimestampMs,
    'frames': analyzedFrames,
    'timerTransitions': timerTransitions,
    'profiles': {
      for (final profile in PolychordRegisterSelectorProfile.values)
        profile.selectorId: runtimes[profile]!.finish(endTimestampMs),
    },
  };
}

Map<String, Object?> _analyzeCommittedEvents(Map<String, dynamic> request) {
  final id = _requiredString(request['id'], 'id');
  final outputEvents = <Map<String, Object?>>[];
  final eventIds = <String>{};
  var previousTimestampMs = 0;
  for (final (index, raw) in (request['events'] as List<dynamic>).indexed) {
    final event = raw as Map<String, dynamic>;
    final eventId = _requiredString(event['id'], 'events[$index].id');
    if (!eventIds.add(eventId)) {
      throw ArgumentError('committed event IDs must be distinct');
    }
    final timestampMs = _requiredInt(
      event['timestampMs'],
      'events[$index].timestampMs',
      minimum: 0,
    );
    if (index > 0 && timestampMs < previousTimestampMs) {
      throw ArgumentError('committed event timestamps must be nondecreasing');
    }
    previousTimestampMs = timestampMs;
    final durationMs = _requiredInt(
      event['durationMs'],
      'events[$index].durationMs',
      minimum: 0,
    );
    final notes = _midiNotes(event['midiNotes'], 'events[$index].midiNotes');
    final primary = _analyzePrimary(notes, _defaultContext);
    final decisions = {
      for (final profile in PolychordRegisterSelectorProfile.values)
        profile: _selector.decide(notes, profile: profile),
    };
    final anySelected = decisions.values.any(
      (decision) => decision.selected != null,
    );
    final contextAudit = anySelected ? _auditPrimaryContexts(notes) : null;
    outputEvents.add({
      'id': eventId,
      'timestampMs': timestampMs,
      'durationMs': durationMs,
      'midiNotes': notes,
      'primary': _primaryJson(primary, _defaultContext),
      'primaryContextAudit': contextAudit,
      'profiles': {
        for (final profile in PolychordRegisterSelectorProfile.values)
          profile.selectorId: {
            'decision': decisions[profile]!.toJson(),
            'outerReasonCodes':
                decisions[profile]!.selected != null && primary == null
                ? const ['primary-not-displayable']
                : const <String>[],
          },
      },
    });
  }
  return {
    'schema': 'polychord-development-exposure-dart-piece/1',
    'kind': 'committedEvents',
    'id': id,
    'events': outputEvents,
  };
}

final class _ProfileRuntime {
  _ProfileRuntime(this.profile);

  final PolychordRegisterSelectorProfile profile;
  final gate = PolychordStableDisplayGate();
  final frameCounts = <String, int>{};
  final dwellCounts = <String, int>{};
  final transitionCounts = <String, int>{};
  final selectorReasonCounts = <String, int>{};
  final clearReasonCounts = <String, int>{};
  final integratedTraceCounts = <String, int>{};
  final distinctIdentities = <String, Map<String, Object>>{};
  final distinctAssignments = <String, Map<String, Object>>{};
  final latenciesMs = <int>[];
  final episodes = <Map<String, Object?>>[];

  int? _pendingStartedAtMs;
  Map<String, Object?>? _openEpisode;
  var _suppressedUnstableSelections = 0;

  PolychordStableDisplayResult observe({
    required int timestampMs,
    required PolychordCandidate? rawSelected,
    required bool primaryDisplayable,
    required _Observation observation,
    required ChordCandidate? primary,
    required Map<String, Object?>? contextAudit,
    required PolychordRegisterDecision? decision,
    required String trigger,
  }) {
    final oldPending = gate.pending;
    final oldPendingStartedAtMs = _pendingStartedAtMs;
    final result = gate.step(
      timestamp: Duration(milliseconds: timestampMs),
      rawSelected: rawSelected,
      primaryDisplayable: primaryDisplayable,
      soundingMidiNotes: observation.soundingMidiNotes,
    );
    _increment(transitionCounts, result.transition.name);
    if (result.reasonCode != null &&
        result.transition == PolychordDisplayTransition.clear) {
      _increment(clearReasonCounts, result.reasonCode!);
    }

    final newPending = gate.pending;
    if (newPending != null && newPending != oldPending) {
      if (oldPending != null) _suppressedUnstableSelections++;
      _pendingStartedAtMs = timestampMs;
    } else if (oldPending != null && newPending == null) {
      if (result.transition == PolychordDisplayTransition.appearance ||
          result.transition == PolychordDisplayTransition.change) {
        final latency = timestampMs - (oldPendingStartedAtMs ?? timestampMs);
        latenciesMs.add(latency);
      } else {
        _suppressedUnstableSelections++;
      }
      _pendingStartedAtMs = null;
    }
    if (result.transition == PolychordDisplayTransition.appearance ||
        result.transition == PolychordDisplayTransition.change) {
      if (result.transition == PolychordDisplayTransition.change) {
        _closeEpisode(
          timestampMs: timestampMs,
          observation: observation,
          endTransition: 'change',
          reasonCode: null,
        );
      }
      final latency = latenciesMs.isEmpty ? null : latenciesMs.last;
      PolychordSelectorTrace? selectedTrace;
      for (final trace
          in decision?.traces ?? const <PolychordSelectorTrace>[]) {
        if (trace.candidate == result.displayed) {
          selectedTrace = trace;
          break;
        }
      }
      if (selectedTrace == null) {
        throw StateError('display appearance lacks its selector evidence');
      }
      _openEpisode = {
        'startMs': timestampMs,
        'startTrigger': trigger,
        'sourceStartAfterEventIndex': observation.afterEventIndex,
        'selected': result.displayed!.toJson(),
        'soundingMidiNotes': observation.soundingMidiNotes,
        'pressedMidiNotes': observation.pressedMidiNotes,
        'sustainedMidiNotes': observation.sustainedMidiNotes,
        'pedalDown': observation.pedalDown,
        'primary': _primaryJson(primary, _defaultContext),
        'primaryContextAudit': contextAudit,
        'selectionEvidence': selectedTrace.toJson(),
        'appearanceLatencyMs': latency,
      };
    } else if (result.transition == PolychordDisplayTransition.clear) {
      _closeEpisode(
        timestampMs: timestampMs,
        observation: observation,
        endTransition: trigger == 'midi-end' ? 'midi-end' : 'clear',
        reasonCode: result.reasonCode,
      );
    }
    return result;
  }

  void measureFrame({
    required _Observation observation,
    required PolychordRegisterDecision decision,
    required bool primaryDisplayable,
    required int dwellMs,
    required bool timestampTerminal,
  }) {
    _increment(frameCounts, 'total');
    if (dwellMs == 0) _increment(frameCounts, 'zeroDwell');
    if (timestampTerminal) _increment(frameCounts, 'timestampTerminal');
    if (observation.soundingMidiNotes.isNotEmpty) {
      _increment(frameCounts, 'sounding');
      _add(dwellCounts, 'sounding', dwellMs);
    }
    if (decision.candidates.isNotEmpty) {
      _increment(frameCounts, 'withCandidates');
      _add(dwellCounts, 'withCandidates', dwellMs);
    }
    if (decision.selected != null) {
      _increment(frameCounts, 'rawSelected');
      _add(dwellCounts, 'rawSelected', dwellMs);
      if (!primaryDisplayable) {
        _increment(frameCounts, 'selectedPrimaryUnavailable');
        _add(dwellCounts, 'selectedPrimaryUnavailable', dwellMs);
      }
    }
    _add(frameCounts, 'candidateInstances', decision.candidates.length);
    for (final reason in decision.reasonCodes) {
      _increment(selectorReasonCounts, reason);
    }
    for (final trace in decision.traces) {
      _increment(integratedTraceCounts, 'total');
      if (trace.identityAssignmentCount > 1) {
        _increment(integratedTraceCounts, 'identityWithMultipleAssignments');
      }
      if (trace.integratedTertian.compact) {
        _increment(integratedTraceCounts, 'compact');
      }
      if (trace.integratedTertian.rootedNinth) {
        _increment(integratedTraceCounts, 'rootedNinth');
      }
      if (trace.integratedTertian.rootedSeventhExtension) {
        _increment(integratedTraceCounts, 'rootedSeventhExtension');
      }
      if (trace.removedByAssignmentVeto) {
        _increment(integratedTraceCounts, 'removedByAssignmentVeto');
      }
      if (trace.removedByIntegratedTertianVeto) {
        _increment(integratedTraceCounts, 'removedByIntegratedTertianVeto');
      }
      if (trace.survived) {
        _increment(integratedTraceCounts, 'survived');
      }
    }
    for (final candidate in decision.candidates) {
      final identity = candidate.identity.toJson();
      distinctIdentities[jsonEncode(identity)] = identity;
      final assignment = <String, Object>{
        'identity': identity,
        'lowerMidiNotes': candidate.lower.midiNotes,
        'upperMidiNotes': candidate.upper.midiNotes,
      };
      distinctAssignments[jsonEncode(assignment)] = assignment;
    }
  }

  Map<String, Object?> finish(int endTimestampMs) {
    if (_openEpisode != null) {
      throw StateError(
        '${profile.selectorId} still has an open episode at $endTimestampMs ms',
      );
    }
    return {
      'selectorId': profile.selectorId,
      'frameCounts': _sortedCounts(frameCounts),
      'dwellMs': _sortedCounts(dwellCounts),
      'transitionCounts': _sortedCounts(transitionCounts),
      'selectorReasonCounts': _sortedCounts(selectorReasonCounts),
      'clearReasonCounts': _sortedCounts(clearReasonCounts),
      'traceCounts': _sortedCounts(integratedTraceCounts),
      'suppressedUnstableSelections': _suppressedUnstableSelections,
      'appearanceLatenciesMs': latenciesMs,
      'displayedMs': episodes.fold<int>(
        0,
        (total, episode) => total + (episode['durationMs']! as int),
      ),
      'stableEpisodes': episodes,
      'distinctIdentities': [
        for (final key in distinctIdentities.keys.toList()..sort())
          distinctIdentities[key],
      ],
      'distinctAssignments': [
        for (final key in distinctAssignments.keys.toList()..sort())
          distinctAssignments[key],
      ],
    };
  }

  void _closeEpisode({
    required int timestampMs,
    required _Observation observation,
    required String endTransition,
    required String? reasonCode,
  }) {
    final episode = _openEpisode;
    if (episode == null) return;
    final startMs = episode['startMs']! as int;
    episodes.add({
      'episodeIndex': episodes.length,
      ...episode,
      'endMs': timestampMs,
      'durationMs': timestampMs - startMs,
      'sourceEndAfterEventIndex': observation.afterEventIndex,
      'endTransition': endTransition,
      'endReasonCode': reasonCode,
    });
    _openEpisode = null;
  }
}

final class _Observation {
  const _Observation({
    required this.afterEventIndex,
    required this.timestampMs,
    required this.pressedMidiNotes,
    required this.sustainedMidiNotes,
    required this.soundingMidiNotes,
    required this.pedalDown,
  });

  factory _Observation.fromJson(Map<String, dynamic> json, String context) {
    final pressed = _midiNotes(
      json['pressedMidiNotes'],
      '$context.pressedMidiNotes',
    );
    final sustained = _midiNotes(
      json['sustainedMidiNotes'],
      '$context.sustainedMidiNotes',
    );
    final sounding = _midiNotes(
      json['soundingMidiNotes'],
      '$context.soundingMidiNotes',
    );
    final union = {...pressed, ...sustained}.toList()..sort();
    if (jsonEncode(union) != jsonEncode(sounding)) {
      throw ArgumentError('$context.soundingMidiNotes must equal state union');
    }
    if (pressed.toSet().intersection(sustained.toSet()).isNotEmpty) {
      throw ArgumentError('$context pressed and sustained notes overlap');
    }
    final pedalDown = json['pedalDown'];
    if (pedalDown is! bool) {
      throw ArgumentError('$context.pedalDown must be a boolean');
    }
    return _Observation(
      afterEventIndex: _requiredInt(
        json['afterEventIndex'],
        '$context.afterEventIndex',
        minimum: 0,
      ),
      timestampMs: _requiredInt(
        json['timestampMs'],
        '$context.timestampMs',
        minimum: 0,
      ),
      pressedMidiNotes: pressed,
      sustainedMidiNotes: sustained,
      soundingMidiNotes: sounding,
      pedalDown: pedalDown,
    );
  }

  final int afterEventIndex;
  final int timestampMs;
  final List<int> pressedMidiNotes;
  final List<int> sustainedMidiNotes;
  final List<int> soundingMidiNotes;
  final bool pedalDown;

  Map<String, Object> toJson() => {
    'afterEventIndex': afterEventIndex,
    'timestampMs': timestampMs,
    'pressedMidiNotes': pressedMidiNotes,
    'sustainedMidiNotes': sustainedMidiNotes,
    'soundingMidiNotes': soundingMidiNotes,
    'pedalDown': pedalDown,
  };
}

void _validateTimeline(List<_Observation> frames, int endTimestampMs) {
  var lastTimestamp = 0;
  for (var index = 0; index < frames.length; index++) {
    final frame = frames[index];
    if (frame.afterEventIndex != index) {
      throw ArgumentError('frames[$index].afterEventIndex must equal $index');
    }
    if (index > 0 && frame.timestampMs < lastTimestamp) {
      throw ArgumentError('frame timestamps must be nondecreasing');
    }
    if (frame.timestampMs > endTimestampMs) {
      throw ArgumentError('frame $index occurs after endTimestampMs');
    }
    lastTimestamp = frame.timestampMs;
  }
}

ChordCandidate? _analyzePrimary(List<int> midiNotes, AnalysisContext context) {
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
  final ranked = _analyzer.analyze(
    input,
    context: context,
    voicing: ObservedVoicing.fromMidi(midiNotes),
  );
  return ranked.isEmpty ? null : ranked.first;
}

Map<String, Object?> _auditPrimaryContexts(List<int> midiNotes) {
  final entries = <Map<String, Object?>>[];
  final distinct = <String, Map<String, Object?>>{};
  var displayableCount = 0;
  for (final entry in _contextAuditEntries) {
    final primary = _analyzePrimary(midiNotes, entry.context);
    if (primary != null) displayableCount++;
    final primaryJson = _primaryJson(primary, entry.context);
    final identityJson = _primaryIdentityJson(primary);
    if (identityJson != null) {
      distinct[jsonEncode(identityJson)] = identityJson;
    }
    entries.add({
      'contextId': entry.id,
      'displayable': primary != null,
      'primary': primaryJson,
    });
  }
  return {
    'contextCount': entries.length,
    'displayableCount': displayableCount,
    'availabilityInvariant':
        displayableCount == 0 || displayableCount == entries.length,
    'entries': entries,
    'distinctPrimaryIdentities': [
      for (final key in distinct.keys.toList()..sort()) distinct[key],
    ],
  };
}

Map<String, Object?>? _primaryJson(
  ChordCandidate? candidate,
  AnalysisContext context,
) {
  if (candidate == null) return null;
  final identity = candidate.identity;
  final presentation = ChordPresentationBuilder.fromIdentity(
    identity: identity,
    tonality: context.tonality,
    notation: ChordNotationStyle.textual,
  );
  return {
    'identity': _primaryIdentityJson(candidate)!,
    'symbol': presentation.symbol.toString(),
    'longLabel': presentation.semanticLabel,
    'cost': candidate.cost,
  };
}

Map<String, Object?>? _primaryIdentityJson(ChordCandidate? candidate) {
  if (candidate == null) return null;
  final identity = candidate.identity;
  return {
    'rootPc': identity.rootPc,
    'bassPc': identity.bassPc,
    'quality': identity.quality.name,
    'extensions': [
      for (final extension
          in identity.extensions.toList()
            ..sort((a, b) => a.index.compareTo(b.index)))
        extension.name,
    ],
    'presentIntervalsMask': identity.presentIntervalsMask,
  };
}

Map<String, Object?> _gateResultJson(PolychordStableDisplayResult result) => {
  'displayed': result.displayed?.toJson(),
  'transition': result.transition.name,
  'reasonCode': result.reasonCode,
};

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
  final tonalities = [
    for (final tonic in majorTonics) Tonality(tonic, TonalityMode.major),
    for (final tonic in minorTonics) Tonality(tonic, TonalityMode.minor),
  ];
  return [
    for (final tonality in tonalities)
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

List<int> _midiNotes(Object? value, String context) {
  if (value is! List<dynamic>) {
    throw ArgumentError('$context must be an integer array');
  }
  final notes = <int>[];
  for (var index = 0; index < value.length; index++) {
    notes.add(
      _requiredInt(value[index], '$context[$index]', minimum: 0, maximum: 127),
    );
  }
  for (var index = 1; index < notes.length; index++) {
    if (notes[index] <= notes[index - 1]) {
      throw ArgumentError('$context must be strictly increasing');
    }
  }
  return List<int>.unmodifiable(notes);
}

int _requiredInt(
  Object? value,
  String context, {
  required int minimum,
  int? maximum,
}) {
  if (value is! int) throw ArgumentError('$context must be an integer');
  if (value < minimum || (maximum != null && value > maximum)) {
    throw RangeError('$context is outside its supported range');
  }
  return value;
}

String _requiredString(Object? value, String context) {
  if (value is! String || value.trim().isEmpty) {
    throw ArgumentError('$context must be a nonempty string');
  }
  return value;
}

void _increment(Map<String, int> counts, String key) {
  counts[key] = (counts[key] ?? 0) + 1;
}

void _add(Map<String, int> counts, String key, int value) {
  counts[key] = (counts[key] ?? 0) + value;
}

Map<String, int> _sortedCounts(Map<String, int> counts) => {
  for (final key in counts.keys.toList()..sort()) key: counts[key]!,
};
