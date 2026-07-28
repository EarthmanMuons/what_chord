import 'package:test/test.dart';

import 'package:whatchord/testing.dart';
import 'package:whatchord/whatchord.dart';

final _analyzer = ChordAnalyzer();

void main() {
  const minDuration = Duration(milliseconds: 300);
  const cMajor = {60, 64, 67};
  const fMajor = {65, 69, 72};
  const gMajor = {55, 59, 62};

  final context = makeAnalysisContext();
  final start = DateTime(2026, 1, 1, 12);
  DateTime at(int ms) => start.add(Duration(milliseconds: ms));

  CaptureFrame frameFor(Set<int> midiNotes) {
    final voicing = ObservedVoicing.fromMidi(midiNotes);
    final input = ChordInput(
      pcMask: maskOf(midiNotes.map((note) => note % 12)),
      bassPc: voicing.bassMidi % 12,
      noteCount: midiNotes.length,
    );
    final candidates = _analyzer.analyze(
      input,
      context: context,
      voicing: voicing,
    );
    return CaptureFrame(
      input: input,
      voicing: voicing,
      candidates: candidates,
      tonality: context.tonality,
    );
  }

  late ChordEventSegmenter segmenter;

  setUp(() {
    segmenter = ChordEventSegmenter(minChordDuration: minDuration);
  });

  test('commits a held chord on release with onset timestamp and duration', () {
    final c = frameFor(cMajor);
    expect(segmenter.onFrame(c, at(0)), isEmpty);

    final committed = segmenter.onFrame(null, at(1000));
    expect(committed, hasLength(1));
    final event = committed.single;
    expect(event.identity, c.identity);
    expect(event.timestamp, at(0));
    expect(event.duration, const Duration(milliseconds: 1000));
  });

  test('drops a chord released before minChordDuration', () {
    segmenter.onFrame(frameFor(cMajor), at(0));
    expect(segmenter.onFrame(null, at(200)), isEmpty);
  });

  test(
    'a challenger that vanishes was a blip; the chord continues unbroken',
    () {
      final c = frameFor(cMajor);
      segmenter.onFrame(c, at(0));
      expect(segmenter.onFrame(frameFor(fMajor), at(500)), isEmpty);
      expect(segmenter.onFrame(c, at(600)), isEmpty);
      expect(segmenter.pendingDeadline, isNull);

      final committed = segmenter.onFrame(null, at(1500));
      expect(committed, hasLength(1));
      expect(committed.single.identity, c.identity);
      expect(committed.single.duration, const Duration(milliseconds: 1500));
    },
  );

  test(
    'a stabilized challenger ends the chord and is backdated to its onset',
    () {
      final c = frameFor(cMajor);
      final f = frameFor(fMajor);
      segmenter.onFrame(c, at(0));
      expect(segmenter.onFrame(f, at(500)), isEmpty);
      expect(segmenter.pendingDeadline, at(800));

      // The next frame past the deadline promotes the challenger and commits
      // the current chord as ending at the challenger's onset.
      final committed = segmenter.onFrame(f, at(900));
      expect(committed, hasLength(1));
      expect(committed.single.identity, c.identity);
      expect(committed.single.duration, const Duration(milliseconds: 500));

      final rest = segmenter.onFrame(null, at(1400));
      expect(rest, hasLength(1));
      expect(rest.single.identity, f.identity);
      expect(rest.single.timestamp, at(500), reason: 'backdated to onset');
      expect(rest.single.duration, const Duration(milliseconds: 900));
    },
  );

  test('resolveDue promotes a challenger without a new frame', () {
    final c = frameFor(cMajor);
    final f = frameFor(fMajor);
    segmenter.onFrame(c, at(0));
    segmenter.onFrame(f, at(500));

    expect(segmenter.resolveDue(at(700)), isEmpty, reason: 'not yet due');
    final committed = segmenter.resolveDue(at(800));
    expect(committed, hasLength(1));
    expect(committed.single.identity, c.identity);

    final rest = segmenter.flush(at(1400));
    expect(rest.single.identity, f.identity);
    expect(rest.single.timestamp, at(500));
  });

  test('release with an unresolved challenger ends the chord at its onset '
      'and drops the challenger', () {
    final c = frameFor(cMajor);
    segmenter.onFrame(c, at(0));
    segmenter.onFrame(frameFor(fMajor), at(500));

    final committed = segmenter.onFrame(null, at(600));
    expect(committed, hasLength(1));
    expect(committed.single.identity, c.identity);
    expect(committed.single.duration, const Duration(milliseconds: 500));

    expect(segmenter.flush(at(2000)), isEmpty);
  });

  test('a new challenger replaces the old one and restarts the clock', () {
    final c = frameFor(cMajor);
    final g = frameFor(gMajor);
    segmenter.onFrame(c, at(0));
    segmenter.onFrame(frameFor(fMajor), at(500));
    segmenter.onFrame(g, at(600));
    expect(segmenter.pendingDeadline, at(900));

    final committed = segmenter.onFrame(g, at(1000));
    expect(committed.single.identity, c.identity);
    expect(committed.single.duration, const Duration(milliseconds: 600));
  });

  test('same-identity frames neither re-segment nor update the snapshot', () {
    final low = frameFor(cMajor);
    final withDoubling = frameFor({...cMajor, 72});
    expect(low.identity, withDoubling.identity, reason: 'sanity');

    segmenter.onFrame(low, at(0));
    segmenter.onFrame(withDoubling, at(400));

    final committed = segmenter.onFrame(null, at(1000));
    expect(committed, hasLength(1));
    expect(committed.single.voicing, same(low.voicing), reason: 'snapshot');
    expect(committed.single.duration, const Duration(milliseconds: 1000));
  });

  test('release after the challenger deadline commits both, oldest first', () {
    final c = frameFor(cMajor);
    final f = frameFor(fMajor);
    segmenter.onFrame(c, at(0));
    segmenter.onFrame(f, at(500));

    final committed = segmenter.onFrame(null, at(900));
    expect(committed, hasLength(2));
    expect(committed[0].identity, c.identity);
    expect(committed[0].duration, const Duration(milliseconds: 500));
    expect(committed[1].identity, f.identity);
    expect(committed[1].timestamp, at(500));
    expect(committed[1].duration, const Duration(milliseconds: 400));
  });

  test('reset drops the current chord and any challenger', () {
    segmenter.onFrame(frameFor(cMajor), at(0));
    segmenter.onFrame(frameFor(fMajor), at(500));
    segmenter.reset();
    expect(segmenter.pendingDeadline, isNull);
    expect(segmenter.flush(at(5000)), isEmpty);
  });

  test('active tracks the accumulating chord from onset', () {
    expect(segmenter.active, isNull);
    expect(segmenter.activeSince, isNull);

    final c = frameFor(cMajor);
    segmenter.onFrame(c, at(0));
    expect(segmenter.active?.identity, c.identity);
    expect(segmenter.activeSince, at(0));

    segmenter.onFrame(null, at(1000));
    expect(segmenter.active, isNull);
    expect(segmenter.activeSince, isNull);
  });

  test(
    'active holds through a pending challenger and backdates on takeover',
    () {
      final c = frameFor(cMajor);
      final f = frameFor(fMajor);
      segmenter.onFrame(c, at(0));
      segmenter.onFrame(f, at(500));
      expect(segmenter.active?.identity, c.identity);
      expect(segmenter.activeSince, at(0));

      segmenter.resolveDue(at(500 + minDuration.inMilliseconds));
      expect(segmenter.active?.identity, f.identity);
      expect(segmenter.activeSince, at(500));
    },
  );
}
