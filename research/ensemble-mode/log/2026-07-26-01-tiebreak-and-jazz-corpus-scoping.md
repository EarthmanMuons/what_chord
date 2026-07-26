# 2026-07-26: Tiebreak round and jazz corpus, scoped

**Goal.** Scope the two leads this initiative left open at close (entries
2026-07-25-05 and -06): the naming residual that a perfect key cannot fix, and
the missing jazz-comping corpus. Prompted by the whatkey-local initiative's
decomposition (its log 2026-07-26-04) sizing the exact-key naming share at 30%
of remaining ensemble misses.

**Setup.** The rootless harness gained an annotated-key miss-shape tally
(expected quality against the chosen root offset and quality); run on the DCML
dev split, stable arm. Corpus inventory read from the pinned local ChoCo
checkout; licenses from ChoCo's LICENSE.md.

**What happened.**

Annotated-key (oracle) miss shapes, DCML dev, 543 misses:

| Expected, then chosen                         | Count | Share |
| --------------------------------------------- | ----- | ----- |
| halfDiminished7, then major7 a semitone below | 264   | 49%   |
| dominant7, then dominant7 a tritone away      | 163   | 30%   |
| major7, then halfDiminished7 a semitone above | 49    | 9%    |
| minor7, then major triad a minor third up     | 29    | 5%    |
| dominant7Sharp5, then plain dominant7         | 23    | 4%    |
| everything else                               | 15    | 3%    |

Two confusion pairs are 88% of the pure naming residual, and both are
structural, not noise:

- The semitone pair (58% with its mirror): a rootless half-diminished seventh
  and the rootless major seventh a semitone below sound the same three tones (B
  half-diminished and B flat major seventh both leave D-F-A). The tiebreak
  currently favors the major-seventh reading; the key it already holds carries
  the disambiguating cue (the half-diminished root sits on the leading tone of
  major or the second degree of minor, both idiomatic; a major seventh on those
  degrees is not).
- The tritone pair (30%): the two dominants sharing a guide-tone tritone,
  exactly the dyad-shell question entry -06 parked. The key cue is V7 versus the
  flat-II substitution; the bass and color tones are secondary cues.

Jazz corpus inventory, pinned local ChoCo checkout (all with Harte chords and
key annotations in JAMS form):

| Partition       | Size          | License via ChoCo | Fit                                                                        |
| --------------- | ------------- | ----------------- | -------------------------------------------------------------------------- |
| weimar (WJazzD) | 916 files     | CC BY 4.0         | Primary candidate: real jazz harmony with timing, solo-level chord changes |
| jaah            | 97 standards  | CC BY-NC-SA 4.0   | Secondary, build-only like Isophonics; audio-aligned with beats            |
| ireal-pro       | 71,780 charts | CC BY 4.0         | Census and priors at scale; sample for fixtures                            |
| real-book       | 5,700         | listed CC BY 4.0  | Skip for now: fake-book provenance deserves its own diligence              |
| jazz-corpus     | 160           | CC BY 4.0         | Too small to matter next to weimar                                         |

The pipeline shape already exists: voicing synthesis from chord symbols (the
Isophonics extractor pattern) plus root stripping (the rootless harness pattern)
yields a jazz-comping fixture set with expected identities and keys; the
ensemble numbers would finally rest on the genre the mode is for, with
seventh-chord vocabulary throughout rather than pop triads.

**Plain-English reading.** When the key is right and the ensemble mode still
names the wrong chord, it is almost always one of two specific coin flips: "is
this shell the half-diminished chord or the major seventh a half step down," and
"which of the two tritone-related dominants is it." Both coins can be weighted
by information the engine already holds. And the jazz data problem turns out to
be mostly solved already: the corpus checkout we already pin contains the Weimar
Jazz Database under a permissive license, with everything needed to build the
missing corpus.

**Decisions.** Scoping only; no engine changes. The proposed follow-up
initiative: freeze a weimar-based comping fixture set and split, then target the
two confusion pairs with degree-aware tiebreak rules, measured against the
existing comping suite (which must keep passing exactly) and the new corpus,
with the DCML synthesis as the continuity ruler.

**Next.** A product/research decision on opening that initiative.
