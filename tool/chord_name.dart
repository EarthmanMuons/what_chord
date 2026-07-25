// tool/chord_name.dart
//
// Shows the top-ranked chord name in all four forms: symbolic, textual,
// idiomatic (spoken), and academic (long-form).
//
// Usage: dart run tool/chord_name.dart [notes...] [options]
//
// Run with --help for examples and options.

import 'dart:io';

import 'package:whatchord/whatchord.dart';

import 'src/chord_id_engine.dart';

final _analyzer = ChordAnalyzer();

const _usage = '''
Usage:
  dart run tool/chord_name.dart [notes...] [options]

Examples:
  dart run tool/chord_name.dart C E G
  dart run tool/chord_name.dart C E G Bb D --bass=C
  dart run tool/chord_name.dart 60 64 67 70
  dart run tool/chord_name.dart C Eb G Bb --key=C:min
  dart run tool/chord_name.dart C E G --symbolic
  dart run tool/chord_name.dart C E G Bb --top=3

Notes may be pitch names or MIDI note numbers.

Options:
  -h, --help        Show this help text.
  -t, --top=N       Number of ranked candidates to show. Default: 1.
  -b, --bass=PC     Set the bass pitch class, adding it to the sounding notes
                    when needed.
  -k, --key=KEY     Tonality for tie-breaks/spelling. Default: C:maj.
                    Examples: C, C:maj, A:min, Eb:maj, F#:min.
      --ensemble    Ensemble playing context: rootless voicings may be named
                    on an implied (unplayed) root.

Output form (mutually exclusive; prints just the name, no label):
  --symbolic        Symbol notation (e.g. Cmaj7).
  --textual         Text notation (e.g. Cmaj7).
  --idiomatic       Spoken/idiomatic name (e.g. C major seventh).
  --academic        Long-form academic name.
''';

void main(List<String> args) {
  if (_hasFlag(args, 'help', 'h')) {
    stdout.write(_usage);
    return;
  }

  const outputForms = ['symbolic', 'textual', 'idiomatic', 'academic'];
  final selectedForms = outputForms
      .where((f) => _hasFlag(args, f, ''))
      .toList();
  if (selectedForms.length > 1) {
    stderr.writeln(
      'Only one output form flag may be used at a time: '
      '--${selectedForms.join(', --')}',
    );
    exitCode = 2;
    return;
  }
  final outputForm = selectedForms.isEmpty ? null : selectedForms.first;

  final unknownFlags = _unknownFlags(args);
  if (unknownFlags.isNotEmpty) {
    stderr.writeln(
      'Unknown flag${unknownFlags.length == 1 ? '' : 's'}: '
      '${unknownFlags.join(', ')}',
    );
    stderr.writeln('Use --help to see supported options.');
    exitCode = 2;
    return;
  }

  if (args.isEmpty) {
    stderr.writeln('Provide notes (pitch names or MIDI numbers).');
    stderr.writeln('');
    stderr.write(_usage);
    exitCode = 2;
    return;
  }

  final noteTokens = _readNoteTokens(args).expand(_splitNoteToken).toList();
  if (noteTokens.isEmpty) {
    stderr.writeln('No notes provided.');
    exitCode = 2;
    return;
  }

  final parsed = _parseNotes(noteTokens);
  final midi = parsed.midiNotes;
  final pcs = parsed.pitchClasses;

  if (pcs.isEmpty) {
    stderr.writeln('Could not parse any notes.');
    exitCode = 2;
    return;
  }

  final top = _readIntFlag(args, 'top', 't') ?? 1;

  final bassName = _readStringFlag(args, 'bass', 'b');
  final bassPc = bassName != null
      ? pitchClassFromNoteName(bassName)
      : (midi.isNotEmpty
            ? (midi.reduce((a, b) => a < b ? a : b) % 12)
            : pcs.first);

  final parsedPcMask = _pcMaskFrom(pcs);
  final bassWasMissing = (parsedPcMask & (1 << bassPc)) == 0;
  final pcMask = parsedPcMask | (1 << bassPc);
  final input = ChordInput(
    pcMask: pcMask,
    bassPc: bassPc,
    noteCount:
        (midi.isNotEmpty ? midi.length : pcs.length) + (bassWasMissing ? 1 : 0),
  );

  final keyFlag = _readStringFlag(args, 'key', 'k') ?? 'C:maj';
  final tonality = _parseTonalityFlag(keyFlag);
  final ks = KeySignature.fromTonality(tonality);
  final spellingPolicy = NoteSpellingPolicy(preferFlats: ks.prefersFlats);
  final context = AnalysisContext(
    tonality: tonality,
    keySignature: ks,
    spellingPolicy: spellingPolicy,
    playingContext: _hasFlag(args, 'ensemble', '')
        ? PlayingContext.ensemble
        : PlayingContext.solo,
  );

  final results = _analyzer.analyze(input, context: context);

  if (results.isEmpty) {
    stdout.writeln('No candidates.');
    return;
  }

  final take = results.length < top ? results.length : top;
  final showRank = take > 1;

  for (var i = 0; i < take; i++) {
    final id = results[i].identity;

    final symbolic = chordSymbolTextLabel(
      ChordSymbolBuilder.fromIdentity(
        identity: id,
        tonality: context.tonality,
        notation: ChordNotationStyle.symbolic,
      ),
    );

    final textual = chordSymbolTextLabel(
      ChordSymbolBuilder.fromIdentity(
        identity: id,
        tonality: context.tonality,
        notation: ChordNotationStyle.textual,
      ),
    );

    final idiomatic = ChordSpokenNameFormatter.format(
      identity: id,
      tonality: context.tonality,
    );

    final academic = ChordLongFormFormatter.format(
      identity: id,
      tonality: context.tonality,
    );

    if (outputForm != null) {
      final value = switch (outputForm) {
        'symbolic' => symbolic,
        'textual' => textual,
        'idiomatic' => idiomatic,
        'academic' => academic,
        _ => symbolic,
      };
      if (showRank) {
        stdout.writeln('${i + 1}) $value');
      } else {
        stdout.writeln(value);
      }
      continue;
    }

    if (showRank) stdout.writeln('${i + 1})');
    stdout.writeln('symbolic:  $symbolic');
    stdout.writeln('textual:   $textual');
    stdout.writeln('idiomatic: $idiomatic');
    stdout.writeln('academic:  $academic');
    if (showRank && i < take - 1) stdout.writeln('');
  }
}

int _pcMaskFrom(Iterable<int> notes) {
  var mask = 0;
  for (final n in notes) {
    mask |= 1 << (n % 12);
  }
  return mask;
}

({List<int> midiNotes, List<int> pitchClasses, Map<int, String> pcLabels})
_parseNotes(List<String> tokens) {
  final midi = <int>[];
  final pcs = <int>[];
  final pcLabels = <int, String>{};

  for (final t in tokens) {
    final raw = t.trim();
    if (raw.isEmpty) continue;

    final asInt = int.tryParse(raw);
    if (asInt != null) {
      midi.add(asInt);
      pcs.add(asInt % 12);
      continue;
    }

    final pc = pitchClassFromNoteName(raw);
    pcs.add(pc);
    pcLabels.putIfAbsent(pc, () => raw);
  }

  return (midiNotes: midi, pitchClasses: pcs, pcLabels: pcLabels);
}

Tonality _parseTonalityFlag(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return const Tonality(Tonic.c, TonalityMode.major);

  final compact = s.replaceAll(RegExp(r'\s+'), '');

  String tonicPart;
  String? modePart;
  final colon = compact.indexOf(':');
  if (colon >= 0) {
    tonicPart = compact.substring(0, colon);
    modePart = compact.substring(colon + 1);
  } else {
    tonicPart = compact;
    modePart = null;
  }

  final modeToken = (modePart ?? '').toLowerCase();
  var mode = TonalityMode.major;

  if (modePart != null) {
    if (modeToken == 'min' || modeToken == 'minor') mode = TonalityMode.minor;
    if (modeToken == 'maj' || modeToken == 'major') mode = TonalityMode.major;
  } else {
    final lower = tonicPart.toLowerCase();
    if (lower.endsWith('minor')) {
      mode = TonalityMode.minor;
      tonicPart = tonicPart.substring(0, tonicPart.length - 'minor'.length);
    } else if (lower.endsWith('major')) {
      mode = TonalityMode.major;
      tonicPart = tonicPart.substring(0, tonicPart.length - 'major'.length);
    } else if (lower.endsWith('min')) {
      mode = TonalityMode.minor;
      tonicPart = tonicPart.substring(0, tonicPart.length - 'min'.length);
    } else if (lower.endsWith('maj')) {
      mode = TonalityMode.major;
      tonicPart = tonicPart.substring(0, tonicPart.length - 'maj'.length);
    }
  }

  final tonicAscii = normalizeNoteNameToAscii(tonicPart);
  final tonic = Tonic.tryFromLabel(tonicAscii) ?? Tonic.c;
  return normalizeTonalityForKeySignature(Tonality(tonic, mode));
}

bool _hasFlag(List<String> args, String name, String shortName) {
  return args.contains('--$name') || args.contains('-$shortName');
}

List<String> _unknownFlags(List<String> args) {
  const knownFlags = {
    '--help',
    '--top',
    '--bass',
    '--key',
    '--ensemble',
    '--symbolic',
    '--textual',
    '--idiomatic',
    '--academic',
    '-h',
    '-t',
    '-b',
    '-k',
  };

  final unknown = <String>[];
  for (final arg in args) {
    if (!arg.startsWith('--') && !RegExp(r'^-[A-Za-z]').hasMatch(arg)) {
      continue;
    }
    final flag = arg.split('=').first;
    if (!knownFlags.contains(flag)) unknown.add(flag);
  }
  return unknown;
}

int? _readIntFlag(List<String> args, String name, String shortName) {
  final value = _readStringFlag(args, name, shortName);
  return value == null ? null : int.tryParse(value);
}

String? _readStringFlag(List<String> args, String name, String shortName) {
  final long = '--$name';
  final longPrefix = '$long=';
  final short = '-$shortName';
  final shortPrefix = '$short=';

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith(longPrefix)) return arg.substring(longPrefix.length);
    if (arg == long && i + 1 < args.length) return args[i + 1];
    if (arg.startsWith(shortPrefix)) return arg.substring(shortPrefix.length);
    if (arg == short && i + 1 < args.length) return args[i + 1];
  }

  return null;
}

List<String> _readNoteTokens(List<String> args) {
  const valueFlags = {'--top', '--bass', '--key', '-t', '-b', '-k'};

  final out = <String>[];
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('--') || RegExp(r'^-[A-Za-z]').hasMatch(arg)) {
      final flag = arg.split('=').first;
      if (valueFlags.contains(flag) &&
          !arg.contains('=') &&
          i + 1 < args.length) {
        i++;
      }
      continue;
    }
    out.add(arg);
  }
  return out;
}

Iterable<String> _splitNoteToken(String token) sync* {
  for (final part in token.split(',')) {
    final trimmed = part.trim();
    if (trimmed.isNotEmpty) yield trimmed;
  }
}
