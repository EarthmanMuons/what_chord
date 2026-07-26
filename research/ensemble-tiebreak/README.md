# Ensemble Tiebreak

Closing the ensemble mode's pure naming residual: the misses that remain when
the key is exactly right. The ensemble-mode initiative shipped the mode and
measured it at ~93% top-1 on held-out classical synthesis; the whatkey-local
initiative then closed the key-detection side and decomposed what was left. This
initiative implements the handoff scoped in ensemble-mode log 2026-07-26-01: two
structural confusion pairs are 88% of the annotated-key naming residual, and the
missing jazz-comping corpus turned out to be sitting in the corpus checkout the
project already pins.

Status: complete (log entries -02 through -06). The residual was hypothesis
admission, not tiebreaking: the implied-root generator only proposed roots
inside the key, so secondary and substitute dominants could never be named.
Key-open admission plus two narrow guards (natural colors required for
out-of-key promotion; the half-diminished/major-seventh identical-tones pair
decided by the key) ships as the result.

## Results

Development (paired per solo or piece, inferred-key arm primary): Weimar 83.7%
to 92.9% exact (+0.0786 per solo, 179/3/151, p = 3.5e-30); DCML 92.8% to 96.5%
inferred and 95.9% to 97.3% annotated (+0.0335, 178/1, p = 1.3e-30). Held-out
test split (one shot, log entry -06): stable inferred 87.3% to 94.2% (+0.0628
per solo, 41 wins, zero losses, p = 2.4e-08), reactive 85.5% to 93.1% (46/0, p =
3.5e-09). Preset sensitivity collapsed to within 0.2 points (log entry -04); the
comping suite passes exactly and solo analysis is bit-identical throughout.
Residual floor and mechanisms: log entry -03 (resolution-context dominants,
template-eligibility sharp fives, global-key artifacts); the scoped follow-up is
a resolution-aware relabel of ensemble history.

## Why

- The oracle-key ensemble arm misses 543 of 13,197 DCML dev events, and 88% of
  those misses are two coin flips: a rootless half-diminished seventh read as
  the major seventh a semitone below (the two leave identical sounding tones;
  264 + 49 mirror), and the two tritone-related dominants sharing a guide-tone
  tritone (163, the dyad-shell question ensemble-mode log 2026-07-25-06 parked).
- Both flips can be weighted by information the engine already holds: the scale
  degree of the candidate root in the supplied key (a half-diminished root on
  the leading tone of major or the second degree of minor is idiomatic where a
  major seventh is not; V7 outranks its flat-II substitute absent contrary bass
  evidence).
- Every ensemble number so far rests on classical synthesis. The Weimar Jazz
  Database (456 solos, real jazz vocabulary, per-solo keys) ships in the pinned
  ChoCo checkout under CC BY 4.0, so this initiative finally measures the mode
  on the genre it was built for.

## Contents

- [Protocol](PROTOCOL.md): rulers, guards, and adoption bar; inherits the frozen
  chord-context protocol.
- [Log](log/): dated, append-only record of every experiment and decision.
- Data: the frozen split lives at
  [data/splits/weimar-comping-v1.json](data/splits/weimar-comping-v1.json);
  fixtures are build-only (`build/chord-context/fixtures/weimar-comping-v1`)
  with attribution recorded in their manifest.

Supporting code: the corpus tools live in `tool/chord-context/`
(`weimar_extract.py`, `freeze_weimar_split.py`); measurement reuses
`rootless_corpus.dart` unchanged; engine changes land in `packages/whatchord/`
and must keep solo analysis bit-identical.
