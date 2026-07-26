# 2026-07-26: Initiative start, debate settled, baselines reproduced

**Goal.** Open the local-key initiative: reconcile the "progression analysis
does not help" record with the "key detection is the bottleneck" record, freeze
a protocol, and confirm the shipped baselines still reproduce on the current
engine before any detector work.

**Setup.** Engine commit 0ce8809f. Fixtures: committed `when-in-rome-v1`
(content-hash verified by the harness), locally built `isophonics-nc-v1` under
`build/whatkey-fixtures/`. Shipped detector recipe throughout: HMM, pure profile
emissions (Albrecht-Shanahan, duration-weighted), self-transition 0.9, emission
temperature 0.25, margin floor 0.3, mode tilt 2.

```
dart run tool/whatkey/harness.dart \
  --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --split-file research/whatkey/data/splits/when-in-rome-v1.json \
  --split development --detector hmm \
  --out build/whatkey-local/wir-dev-stable

dart run tool/whatkey/harness.dart \
  --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --split-file research/whatkey/data/splits/when-in-rome-v1.json \
  --split development --detector hmm --decay-half-life-seconds 1 \
  --out build/whatkey-local/wir-dev-reactive

dart run tool/whatkey/harness.dart \
  --fixtures build/whatkey-fixtures/isophonics-nc-v1 \
  --split-file research/whatkey/data/splits/isophonics-nc-v1.json \
  --split development --detector hmm \
  --out build/whatkey-local/iso-dev-stable
```

**What happened.** The debate reconciliation was written up as the founding
document, [../local-key-bottleneck.md](../local-key-bottleneck.md), from a full
re-read of the whatkey, chord-context, and ensemble-mode logs. Verdict in one
line: emission-side progression evidence is dead (tested twice under the HMM,
wash everywhere), while local-key exactness (58-66% against annotated local
keys) is the measured bottleneck for ensemble mode (3-4 points against the
oracle on held-out data), spelling (98% of the residual gap), and solo identity
(0.36-0.48 points); the never-tested lead is transition-side cadence
conditioning, aimed at the dominant/subdominant/relative error mass (~24-27% of
claims, chord-context log 2026-07-20-18).

Baseline reproduction on the current engine matched the logged numbers:

| Run                     | Coverage | Exact | Modulations | Spurious p90 |
| ----------------------- | -------- | ----- | ----------- | ------------ |
| WiR dev, stable (hl30)  | 0.784    | 0.434 | 120/399     | 1            |
| WiR dev, reactive (hl1) | 0.680    | 0.546 | 184/399     | -            |
| Iso dev, stable (hl30)  | 0.922    | 0.775 | 94/192      | 1            |

Logged references: WiR stable 0.78 / 0.434 and reactive 0.68 / 0.546
(key-behavior-modes.md), Iso stable 0.92 / 0.775 with 94/192 (whatkey logs
2026-07-07-23, -26). Exact agreement to the reported precision.

**Decisions.**

- Protocol frozen as written in [../PROTOCOL.md](../PROTOCOL.md): When-in-Rome
  dev is the primary ruler at the reactive operating point, Isophonics dev and
  pop-jazz-v2 are guards, the ASAP x WiR overlap is pre-declared confirmation,
  DCML harnesses are downstream characterization only.
- Experiment order follows the candidate ranking in the founding document:
  transition-kernel reshaping and cadence-conditioned transitions first, since
  they attack the measured error structure directly and need only detector
  options that default to shipped behavior.

**Next.** Implement cadence-conditioned transitions and transition-kernel flags
in `HmmKeyDetector` (defaults byte-identical), then sweep on the primary ruler
with the Isophonics guard.
