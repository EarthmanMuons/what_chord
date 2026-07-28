import 'package:test/test.dart';

import 'package:whatchord/src/services/chord_tone_roles.dart';
import 'package:whatchord/whatchord.dart';

void main() {
  const tonality = Tonality(Tonic.c, TonalityMode.major);

  String spoken(ChordIdentity identity, {Tonality t = tonality}) =>
      ChordSpokenNameFormatter.format(identity: identity, tonality: t);

  test('simple triads', () {
    expect(
      spoken(
        _identity(
          root: 'C',
          quality: ChordQuality.major,
          intervals: const [0, 4, 7],
        ),
      ),
      'C',
    );
    expect(
      spoken(
        _identity(
          root: 'A',
          quality: ChordQuality.minor,
          intervals: const [0, 3, 7],
        ),
      ),
      'A minor',
    );
    expect(
      spoken(
        _identity(
          root: 'B',
          quality: ChordQuality.diminished,
          intervals: const [0, 3, 6],
        ),
      ),
      'B diminished',
    );
    expect(
      spoken(
        _identity(
          root: 'C',
          quality: ChordQuality.augmented,
          intervals: const [0, 4, 8],
        ),
      ),
      'C augmented',
    );
  });

  test('suspended chords', () {
    expect(
      spoken(
        _identity(
          root: 'C',
          quality: ChordQuality.sus2,
          intervals: const [0, 2, 7],
        ),
      ),
      'C sus two',
    );
    expect(
      spoken(
        _identity(
          root: 'C',
          quality: ChordQuality.sus4,
          intervals: const [0, 5, 7],
        ),
      ),
      'C sus',
    );
    expect(
      spoken(
        _identity(
          root: 'C',
          quality: ChordQuality.sus2sus4,
          intervals: const [0, 2, 5, 7],
        ),
      ),
      'C sus two sus four',
    );
  });

  test('sixth chords', () {
    expect(
      spoken(
        _identity(
          root: 'C',
          quality: ChordQuality.major6,
          intervals: const [0, 4, 7, 9],
        ),
      ),
      'C six',
    );
    expect(
      spoken(
        _identity(
          root: 'C',
          quality: ChordQuality.minor6,
          intervals: const [0, 3, 7, 9],
        ),
      ),
      'C minor six',
    );
  });

  test('dominant seventh', () {
    expect(
      spoken(
        _identity(
          root: 'G',
          quality: ChordQuality.dominant7,
          intervals: const [0, 4, 7, 10],
        ),
      ),
      'G seven',
    );
  });

  test('major and minor sevenths', () {
    expect(
      spoken(
        _identity(
          root: 'C',
          quality: ChordQuality.major7,
          intervals: const [0, 4, 7, 11],
        ),
      ),
      'C major seven',
    );
    expect(
      spoken(
        _identity(
          root: 'D',
          quality: ChordQuality.minor7,
          intervals: const [0, 3, 7, 10],
        ),
      ),
      'D minor seven',
    );
    expect(
      spoken(
        _identity(
          root: 'C',
          quality: ChordQuality.halfDiminished7,
          intervals: const [0, 3, 6, 10],
        ),
      ),
      'C half-diminished',
    );
    expect(
      spoken(
        _identity(
          root: 'C',
          quality: ChordQuality.diminished7,
          intervals: const [0, 3, 6, 9],
        ),
      ),
      'C diminished seven',
    );
    expect(
      spoken(
        _identity(
          root: 'C',
          quality: ChordQuality.minorMajor7,
          intervals: const [0, 3, 7, 11],
        ),
      ),
      'C minor major seven',
    );
  });

  test('key example: dominant seventh with flat nine and sharp eleven', () {
    expect(
      spoken(
        _identity(
          root: 'G',
          quality: ChordQuality.dominant7,
          extensions: const {ChordExtension.flat9, ChordExtension.sharp11},
          intervals: const [0, 4, 6, 7, 10, 1],
        ),
      ),
      'G seven flat nine sharp eleven',
    );
  });

  test(
    'absorbs natural extensions into quality: dominant ninth/eleventh/thirteenth',
    () {
      expect(
        spoken(
          _identity(
            root: 'C',
            quality: ChordQuality.dominant7,
            extensions: const {ChordExtension.nine},
            intervals: const [0, 2, 4, 7, 10],
          ),
        ),
        'C nine',
      );
      expect(
        spoken(
          _identity(
            root: 'D',
            quality: ChordQuality.minor7,
            extensions: const {ChordExtension.nine, ChordExtension.eleven},
            intervals: const [0, 2, 3, 5, 7, 10],
          ),
        ),
        'D minor eleven',
      );
      expect(
        spoken(
          _identity(
            root: 'F',
            quality: ChordQuality.major7,
            extensions: const {
              ChordExtension.nine,
              ChordExtension.eleven,
              ChordExtension.thirteen,
            },
            intervals: const [0, 2, 4, 5, 7, 9, 11],
          ),
        ),
        'F major thirteen',
      );
    },
  );

  test('lists residual alterations after absorbed headline', () {
    expect(
      spoken(
        _identity(
          root: 'G',
          quality: ChordQuality.dominant7,
          extensions: const {
            ChordExtension.nine,
            ChordExtension.sharp11,
            ChordExtension.thirteen,
          },
          intervals: const [0, 2, 4, 6, 7, 9, 10],
        ),
      ),
      'G thirteen sharp eleven',
    );
  });

  test('add tones use "add" prefix, not "added"', () {
    expect(
      spoken(
        _identity(
          root: 'G',
          quality: ChordQuality.major,
          extensions: const {ChordExtension.add9},
          intervals: const [0, 2, 4, 7],
        ),
      ),
      'G add nine',
    );
    expect(
      spoken(
        _identity(
          root: 'D',
          quality: ChordQuality.minor7,
          extensions: const {ChordExtension.add11},
          intervals: const [0, 3, 5, 7, 10],
        ),
      ),
      'D minor seven add eleven',
    );
  });

  test('six-nine chords', () {
    expect(
      spoken(
        _identity(
          root: 'C',
          quality: ChordQuality.major6,
          extensions: const {ChordExtension.add9},
          intervals: const [0, 2, 4, 7, 9],
        ),
      ),
      'C six-nine',
    );
    expect(
      spoken(
        _identity(
          root: 'C',
          quality: ChordQuality.minor6,
          extensions: const {ChordExtension.add9},
          intervals: const [0, 2, 3, 7, 9],
        ),
      ),
      'C minor six-nine',
    );
  });

  test('inversion slash chord appends "slash <bass>"', () {
    expect(
      spoken(
        _identity(
          root: 'C',
          bass: 'E',
          quality: ChordQuality.major7,
          intervals: const [0, 4, 7, 11],
        ),
      ),
      'C major seven slash E',
    );
    expect(
      spoken(
        _identity(
          root: 'G',
          bass: 'F',
          quality: ChordQuality.dominant7,
          extensions: const {ChordExtension.flat9, ChordExtension.sharp11},
          intervals: const [0, 4, 6, 7, 10, 1],
        ),
      ),
      'G seven flat nine sharp eleven slash F',
    );
  });

  test('bare flat-seven shell speaks its omitted third', () {
    expect(
      spoken(
        _identity(
          root: 'D',
          quality: ChordQuality.dominant7,
          intervals: const [0, 7, 10],
        ),
      ),
      'D seven omit three',
    );

    // A complete dominant seventh keeps its plain name.
    expect(
      spoken(
        _identity(
          root: 'D',
          quality: ChordQuality.dominant7,
          intervals: const [0, 4, 7, 10],
        ),
      ),
      'D seven',
    );
  });
}

ChordIdentity _identity({
  required String root,
  required ChordQuality quality,
  required List<int> intervals,
  String? bass,
  Set<ChordExtension> extensions = const {},
}) {
  final presentIntervalsMask = _maskOfIntervals(intervals);
  return ChordIdentity(
    rootPc: pitchClassFromNoteName(root),
    bassPc: pitchClassFromNoteName(bass ?? root),
    quality: quality,
    extensions: extensions,
    toneRolesByInterval: ChordToneRoles.build(
      quality: quality,
      extensions: extensions,
      relMask: presentIntervalsMask,
    ),
    presentIntervalsMask: presentIntervalsMask,
  );
}

int _maskOfIntervals(Iterable<int> intervals) {
  var mask = 0;
  for (final interval in intervals) {
    mask |= 1 << (interval % 12);
  }
  return mask;
}
