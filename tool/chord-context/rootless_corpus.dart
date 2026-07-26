// Corpus-scale Track D measurement: how accurately could an ensemble mode
// name rootless voicings? (Follows the 18-case gate, log entry 2026-07-20-16,
// with real chord identities at scale.)
//
// For every DCML event whose expected identity is a seventh chord (guide
// tones present) with its root actually sounding, the root pitch class is
// stripped from the real voicing, simulating a bassist covering the root.
// The stripped voicing is measured three ways against the known identity:
//
//   current:  the shipped engine's top-1 (the no-ensemble-mode baseline).
//   ensembleAnnotated: the missing-root hypothesis set filtered to roots
//     diatonic in the ANNOTATED key; scored as a correct unique answer, an
//     ambiguity (multiple diatonic ghost roots), or a miss. The oracle
//     ceiling for a key-filtered ensemble mode.
//   ensembleInferred: the same, filtered by the closed-loop INFERRED key,
//     the realistic product number.
//   engineAnnotated / engineInferred: the real engine's top-1 under an
//     ensemble playing context with the annotated / closed-loop inferred
//     key. These replace the simulation as the shipping measurement; the
//     simulated unique-correct numbers are the floor they must meet, and
//     unique-correct plus ambiguous is the tiebreak ceiling.
//
// Fully symmetric qualities (diminished7) are reported separately: a
// rootless dim7 has four equal roots and is inherently ambiguous.
//
// Usage mirrors the other harnesses.

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';
import 'package:whatkey/whatkey.dart';

import '../src/chord_id_engine.dart';
import '../whatkey/src/fixtures.dart';

const _take = 10000;

final _analyzer = ChordAnalyzer();

/// Legal colors above an absent root, as semitone intervals: 5th and the
/// tension set b9/9/11/#11/b13/13.
const _legalColors = {1, 2, 5, 6, 7, 8, 9};

/// Qualities that carry both a third and a seventh, so a missing-root
/// template applies. dim7 is included but flagged symmetric downstream.
const _seventhQualities = {
  'dominant7',
  'major7',
  'minor7',
  'minorMajor7',
  'halfDiminished7',
  'diminished7',
  'dominant7Flat5',
  'dominant7Sharp5',
  'major7Flat5',
  'major7Sharp5',
  'minor7Sharp5',
};

void main(List<String> args) {
  final options = _parseArgs(args);
  final fixtureSet = FixtureSet.load(Directory(options['fixtures']!));
  final labels =
      jsonDecode(File(options['labels']!).readAsStringSync())
          as Map<String, dynamic>;
  final pieces = (labels['pieces'] as Map).cast<String, dynamic>();

  final splitFile = SplitFile.load(File(options['split-file']!));
  splitFile.validateAgainst(fixtureSet);
  final titles = splitFile
      .pieceTitles(options['split'] ?? 'development')
      .toSet();
  final selected = [
    for (final fixture in fixtureSet.fixtures)
      if (titles.contains(fixture.title)) fixture,
  ];
  final behavior = KeyBehavior.values.byName(options['behavior'] ?? 'stable');
  final cadenceBoost = double.parse(
    options['cadence-boost'] ?? '${HmmKeyDetector.defaultCadenceBoost}',
  );
  final minEvents = int.parse(options['min-events'] ?? '3');

  var eligible = 0, symmetric = 0;
  var currentExact = 0;
  var engineAnnotatedExact = 0, engineInferredExact = 0;
  // Hindsight arm: the inferred key one event later (the sticky claim after
  // event i+1), the ceiling for a one-event-lag retroactive relabel of the
  // history record (whatkey-local log 2026-07-26-04 Next).
  var engineHindsightExact = 0;
  final annotated = _Outcome();
  final inferred = _Outcome();
  final inferredDominantAware = _Outcome(dominantAware: true);
  final missByQuality = <String, int>{};
  final engineInferredMissByQuality = <String, int>{};
  // Decomposition of engine inferred-key misses (whatkey-local log
  // 2026-07-26-03: the residual concentrates on the dominant that announces
  // a key change, which no cadence-completion signal can reach in time).
  var engineMissKeyError = 0, engineMissAnnouncingDominant = 0;
  final engineMissKeyRelation = <String, int>{};
  // Provenance of the key the inferred arm used: fresh (claimed at the
  // previous event), carried (an older claim held through abstention), or
  // fallback (no claim yet; annotated key stands in). The hindsight split
  // shows how much of the carried deficit a one-event relabel recovers.
  final provenanceTotal = <String, int>{};
  final provenanceExact = <String, int>{};
  final provenanceHindsightExact = <String, int>{};

  for (final fixture in selected) {
    final entries = (pieces[fixture.id] as List).cast<Map>();
    final events = fixture.events;
    final detector = HmmKeyDetector(
      decayHalfLife: behavior.emissionHalfLife,
      cadenceBoost: cadenceBoost,
      minEvents: minEvents,
    );
    // First pass: sticky claim after each event and whether that event
    // produced a fresh claim (vs carrying an older one through abstention).
    final sticky = List<Tonality?>.filled(events.length, null);
    final claimedAt = List<bool>.filled(events.length, false);
    Tonality? running;
    for (var i = 0; i < events.length; i++) {
      final claim = detector.onEvent(events[i]).claim?.tonality;
      claimedAt[i] = claim != null;
      running = claim ?? running;
      sticky[i] = running;
    }

    for (var i = 0; i < events.length; i++) {
      final claimBefore = i == 0 ? null : sticky[i - 1];

      final entry = entries[i].cast<String, dynamic>();
      if (entry['category'] != 'ok') continue;
      final expected = (entry['expected'] as Map?)?.cast<String, dynamic>();
      final quality = expected?['quality'] as String?;
      if (quality == null || !_seventhQualities.contains(quality)) continue;
      final rootPc = expected!['rootPc'] as int;

      final midiNotes = events[i].input;
      if (midiNotes.pcMask & (1 << rootPc) == 0) continue; // root must sound

      // Strip the root pitch class from the real voicing.
      final stripped = [
        for (final note in events[i].voicing.midiNotes)
          if (note % 12 != rootPc) note,
      ];
      if (stripped.length < 3) continue;
      eligible++;

      final annotatedKey = parseTonality(entry['localKey'] as String);
      if (quality == 'diminished7') {
        symmetric++;
        continue;
      }

      var strippedMask = 0;
      for (final note in stripped) {
        strippedMask |= 1 << (note % 12);
      }

      // current: the shipped engine on the stripped voicing.
      final strippedInput = ChordInput(
        pcMask: strippedMask,
        bassPc: stripped.reduce((a, b) => a < b ? a : b) % 12,
        noteCount: stripped.length,
      );
      final strippedVoicing = ObservedVoicing.fromMidi(stripped);
      final ranked = _analyzer.analyze(
        strippedInput,
        context: _contextFor(annotatedKey),
        voicing: strippedVoicing,
        take: _take,
      );
      if (ranked.first.identity.rootPc == rootPc &&
          ranked.first.identity.quality.name == quality) {
        currentExact++;
      }

      bool engineExact(Tonality key) {
        final top = _analyzer
            .analyze(
              strippedInput,
              context: _contextFor(key, PlayingContext.ensemble),
              voicing: strippedVoicing,
            )
            .first
            .identity;
        return top.rootPc == rootPc && top.quality.name == quality;
      }

      final annotatedArmExact = engineExact(annotatedKey);
      if (annotatedArmExact) engineAnnotatedExact++;
      final usedKey = claimBefore ?? annotatedKey;
      final hindsightKey =
          sticky[i + 1 < events.length ? i + 1 : events.length - 1] ??
          annotatedKey;
      final provenance = claimBefore == null
          ? 'fallback'
          : (claimedAt[i - 1] ? 'fresh' : 'carried');
      provenanceTotal[provenance] = (provenanceTotal[provenance] ?? 0) + 1;
      if (engineExact(hindsightKey)) {
        engineHindsightExact++;
        provenanceHindsightExact[provenance] =
            (provenanceHindsightExact[provenance] ?? 0) + 1;
      }
      if (engineExact(usedKey)) {
        provenanceExact[provenance] = (provenanceExact[provenance] ?? 0) + 1;
        engineInferredExact++;
      } else {
        engineInferredMissByQuality[quality] =
            (engineInferredMissByQuality[quality] ?? 0) + 1;
        if (annotatedArmExact) engineMissKeyError++;
        if (_dominantQualities.contains(quality) &&
            annotatedKey.tonicPitchClass == (rootPc + 5) % 12) {
          engineMissAnnouncingDominant++;
        }
        final relation = _keyRelation(usedKey, annotatedKey);
        engineMissKeyRelation[relation] =
            (engineMissKeyRelation[relation] ?? 0) + 1;
      }

      final hypotheses = _rootlessHypotheses(strippedMask);
      annotated.record(hypotheses, annotatedKey, rootPc, quality);
      inferred.record(hypotheses, usedKey, rootPc, quality);
      inferredDominantAware.record(hypotheses, usedKey, rootPc, quality);
      if (!annotated.wasUnique) {
        missByQuality[quality] = (missByQuality[quality] ?? 0) + 1;
      }
    }
  }

  final report = {
    'schema': 'chord-context-rootless-corpus/1',
    'set': fixtureSet.name,
    'behavior': behavior.name,
    'cadenceBoost': cadenceBoost,
    'eligibleSeventhEvents': eligible,
    'symmetricDim7': symmetric,
    'currentEngineExact': currentExact,
    'ensembleAnnotated': annotated.toJson(),
    'ensembleInferred': inferred.toJson(),
    'ensembleInferredDominantAware': inferredDominantAware.toJson(),
    'missByQuality': missByQuality,
    'engineAnnotatedExact': engineAnnotatedExact,
    'engineInferredExact': engineInferredExact,
    'engineHindsightExact': engineHindsightExact,
    'engineInferredProvenanceTotal': provenanceTotal,
    'engineInferredProvenanceExact': provenanceExact,
    'engineHindsightProvenanceExact': provenanceHindsightExact,
    'engineInferredMissByQuality': engineInferredMissByQuality,
    'engineInferredMissKeyError': engineMissKeyError,
    'engineInferredMissAnnouncingDominant': engineMissAnnouncingDominant,
    'engineInferredMissKeyRelation': engineMissKeyRelation,
  };
  final outDir = Directory(options['out'] ?? 'build/chord-context/rootless')
    ..createSync(recursive: true);
  File(
    '${outDir.path}/report.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(report)}\n');

  final scored = eligible - symmetric;
  String pct(num a) => '${(a / scored * 100).toStringAsFixed(1)}%';
  stdout
    ..writeln('rootless corpus [${behavior.name}]: ${fixtureSet.name}')
    ..writeln(
      '  $eligible eligible seventh-chord events '
      '($symmetric symmetric dim7 excluded; $scored scored)',
    )
    ..writeln('  current engine exact (no ensemble mode): ${pct(currentExact)}')
    ..writeln(
      '  ensemble, annotated-key filter: unique-correct '
      '${pct(annotated.uniqueCorrect)}  ambiguous '
      '${pct(annotated.ambiguous)}  miss ${pct(annotated.miss)}',
    )
    ..writeln(
      '  ensemble, inferred-key filter:  unique-correct '
      '${pct(inferred.uniqueCorrect)}  ambiguous '
      '${pct(inferred.ambiguous)}  miss ${pct(inferred.miss)}',
    )
    ..writeln(
      '  engine, annotated key: exact ${pct(engineAnnotatedExact)}; '
      'engine, inferred key: exact ${pct(engineInferredExact)}',
    )
    ..writeln(
      '  ensemble, inferred key + secondary-dominant admission: '
      'unique-correct ${pct(inferredDominantAware.uniqueCorrect)}  ambiguous '
      '${pct(inferredDominantAware.ambiguous)}  miss '
      '${pct(inferredDominantAware.miss)}',
    )
    ..writeln(
      '  engine inferred-key misses: key error (annotated arm exact) '
      '$engineMissKeyError, announcing dominant '
      '$engineMissAnnouncingDominant, used-key relation '
      '$engineMissKeyRelation',
    )
    ..writeln(
      '  engine, hindsight key (one-event lag): exact '
      '${pct(engineHindsightExact)}',
    )
    ..writeln(
      '  inferred arm by key provenance (exact/total): '
      '${provenanceTotal.keys.map((p) => '$p ${provenanceExact[p] ?? 0}/${provenanceTotal[p]}').join(', ')}',
    )
    ..writeln(
      '  hindsight arm by key provenance (exact/total): '
      '${provenanceTotal.keys.map((p) => '$p ${provenanceHindsightExact[p] ?? 0}/${provenanceTotal[p]}').join(', ')}',
    );
  final misses = missByQuality.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (misses.isNotEmpty) {
    stdout.writeln(
      '  non-unique by quality: '
      '${misses.map((e) => '${e.key} ${e.value}').join(', ')}',
    );
  }
  final engineMisses = engineInferredMissByQuality.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (engineMisses.isNotEmpty) {
    stdout.writeln(
      '  engine inferred-key misses by quality: '
      '${engineMisses.map((e) => '${e.key} ${e.value}').join(', ')}',
    );
  }
}

class _Outcome {
  _Outcome({this.dominantAware = false});

  /// When set, dominant7 hypotheses are also admitted if the key they
  /// tonicize (a fifth below the hypothesis root) is diatonic in [key]: the
  /// secondary-dominant admission, so V7-of-x survives the filter while x is
  /// still the claimed key. Headroom probe for the announcing-dominant
  /// residual (whatkey-local log 2026-07-26-03).
  final bool dominantAware;

  int uniqueCorrect = 0;
  int ambiguous = 0;
  int miss = 0;
  bool wasUnique = false;

  void record(
    List<_Hypothesis> hypotheses,
    Tonality key,
    int expectedRoot,
    String expectedQuality,
  ) {
    final diatonic = [
      for (final h in hypotheses)
        if (key.containsPitchClass(h.rootPc) ||
            (dominantAware &&
                h.quality == 'dominant7' &&
                key.containsPitchClass((h.rootPc + 5) % 12)))
          h,
    ];
    wasUnique =
        diatonic.length == 1 &&
        diatonic.single.rootPc == expectedRoot &&
        diatonic.single.quality == expectedQuality;
    if (wasUnique) {
      uniqueCorrect++;
    } else if (diatonic.any(
      (h) => h.rootPc == expectedRoot && h.quality == expectedQuality,
    )) {
      ambiguous++;
    } else {
      miss++;
    }
  }

  Map<String, int> toJson() => {
    'uniqueCorrect': uniqueCorrect,
    'ambiguous': ambiguous,
    'miss': miss,
  };
}

class _Hypothesis {
  _Hypothesis(this.rootPc, this.quality);
  final int rootPc;
  final String quality;
}

const _dominantQualities = {'dominant7', 'dominant7Flat5', 'dominant7Sharp5'};

/// Relation of the key the engine actually used to the annotated local key,
/// mirroring key_error_diagnostic.dart's buckets.
String _keyRelation(Tonality used, Tonality annotated) {
  final sameTonic = used.tonicPitchClass == annotated.tonicPitchClass;
  final sameMode = used.isMinor == annotated.isMinor;
  if (sameTonic && sameMode) return 'exact';
  if (sameTonic) return 'parallel';
  final usedRelativeMajor = used.isMinor
      ? (used.tonicPitchClass + 3) % 12
      : used.tonicPitchClass;
  final annotatedRelativeMajor = annotated.isMinor
      ? (annotated.tonicPitchClass + 3) % 12
      : annotated.tonicPitchClass;
  if (usedRelativeMajor == annotatedRelativeMajor) return 'relative';
  if (used.tonicPitchClass == (annotated.tonicPitchClass + 7) % 12 &&
      sameMode) {
    return 'dominant';
  }
  if (used.tonicPitchClass == (annotated.tonicPitchClass + 5) % 12 &&
      sameMode) {
    return 'subdominant';
  }
  return 'other';
}

List<_Hypothesis> _rootlessHypotheses(int pcMask) {
  final sounding = [
    for (var pc = 0; pc < 12; pc++)
      if (pcMask & (1 << pc) != 0) pc,
  ];
  final results = <_Hypothesis>[];
  for (var root = 0; root < 12; root++) {
    if (pcMask & (1 << root) != 0) continue;
    final intervals = {for (final pc in sounding) (pc - root) % 12};
    final hasMajorThird = intervals.contains(4);
    final hasMinorThird = intervals.contains(3);
    final hasMinorSeventh = intervals.contains(10);
    final hasMajorSeventh = intervals.contains(11);
    if (!(hasMajorThird ^ hasMinorThird)) continue;
    if (!(hasMinorSeventh ^ hasMajorSeventh)) continue;
    final rest = intervals.difference({
      if (hasMajorThird) 4,
      if (hasMinorThird) 3,
      if (hasMinorSeventh) 10,
      if (hasMajorSeventh) 11,
    });
    if (!rest.every(_legalColors.contains)) continue;
    final String quality;
    if (hasMinorThird && hasMinorSeventh) {
      quality = intervals.contains(6) && !intervals.contains(7)
          ? 'halfDiminished7'
          : 'minor7';
    } else if (hasMinorThird && hasMajorSeventh) {
      quality = 'minorMajor7';
    } else if (hasMajorThird && hasMinorSeventh) {
      quality = 'dominant7';
    } else {
      quality = 'major7';
    }
    results.add(_Hypothesis(root, quality));
  }
  return results;
}

AnalysisContext _contextFor(
  Tonality tonality, [
  PlayingContext playingContext = PlayingContext.solo,
]) {
  final keySignature = KeySignature.fromTonality(tonality);
  return AnalysisContext(
    tonality: tonality,
    keySignature: keySignature,
    spellingPolicy: NoteSpellingPolicy(preferFlats: keySignature.prefersFlats),
    playingContext: playingContext,
  );
}

Map<String, String> _parseArgs(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i += 2) {
    if (!args[i].startsWith('--') || i + 1 >= args.length) {
      throw ArgumentError('Expected --flag value pairs, got: ${args[i]}');
    }
    options[args[i].substring(2)] = args[i + 1];
  }
  for (final required in ['fixtures', 'labels', 'split-file']) {
    if (!options.containsKey(required)) {
      throw ArgumentError('Missing required --$required');
    }
  }
  return options;
}
