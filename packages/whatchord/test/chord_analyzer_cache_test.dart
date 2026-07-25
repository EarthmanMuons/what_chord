import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

void main() {
  // Small capacity exercises eviction without hundreds of analyses.
  const capacity = 16;
  late ChordAnalyzer analyzer;

  setUp(() {
    analyzer = ChordAnalyzer(cacheCapacity: capacity);
  });

  test('analyzer cache is bounded to its configured capacity', () {
    final context = _context();

    for (var i = 0; i < capacity + 32; i++) {
      analyzer.analyze(_inputFor(i), context: context);
    }

    expect(analyzer.cacheSize, capacity);
  });

  test('cache hits promote entries before eviction', () {
    final context = _context();
    final first = _inputFor(0);

    final firstResult = analyzer.analyze(first, context: context);

    for (var i = 1; i < capacity; i++) {
      analyzer.analyze(_inputFor(i), context: context);
    }

    expect(analyzer.cacheSize, capacity);
    expect(analyzer.analyze(first, context: context), same(firstResult));

    analyzer.analyze(_inputFor(capacity), context: context);

    expect(analyzer.cacheSize, capacity);
    expect(analyzer.analyze(first, context: context), same(firstResult));
  });

  test('solo and ensemble playing contexts never alias in the cache', () {
    final solo = _context();
    final ensemble = _context(playingContext: PlayingContext.ensemble);
    final input = _inputFor(0);

    final soloResult = analyzer.analyze(input, context: solo);
    final ensembleResult = analyzer.analyze(input, context: ensemble);

    expect(analyzer.cacheSize, 2);
    expect(ensembleResult, isNot(same(soloResult)));
    expect(analyzer.analyze(input, context: solo), same(soloResult));
    expect(analyzer.analyze(input, context: ensemble), same(ensembleResult));
  });
}

AnalysisContext _context({
  PlayingContext playingContext = PlayingContext.solo,
}) {
  const tonality = Tonality(Tonic.c, TonalityMode.major);
  final keySignature = KeySignature.fromTonality(tonality);
  return AnalysisContext(
    tonality: tonality,
    keySignature: keySignature,
    spellingPolicy: NoteSpellingPolicy(preferFlats: keySignature.prefersFlats),
    playingContext: playingContext,
  );
}

ChordInput _inputFor(int index) {
  // Each index maps to a distinct (pcMask, bassPc) and therefore a distinct
  // cache key, so the eviction assertions exercise capacity directly. pcMask
  // keeps bit 0 set (a valid root) and otherwise encodes the index.
  final pcMask = ((index << 1) | 0x1) & 0xFFF;
  final bassPc = index % 12;
  return ChordInput(pcMask: pcMask, bassPc: bassPc, noteCount: 4);
}
