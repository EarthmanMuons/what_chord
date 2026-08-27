# 2026-08-27: Retain the aborted held exposure

**Goal.** Record the v2 held exposure exactly as it failed, determine whether
the error represented production behavior, and preserve the reserve boundary.

**Setup.** Clean release-candidate commit
`6f9c4afb5c03f145646761eeda45cd9c46bd43a1` matched every v2 prospective hash.
Both v1 and v2 output directories were absent. The single registered v2 command
was then executed:

```sh
./.venv/bin/python tool/polychord/held_exposure.py \
  --pop909-root build/whatkey-corpora/POP909-Dataset/POP909 \
  --out-directory build/polychord/product-held-exposure-v2
```

**What happened.** Song 002 completed with zero stable display episodes and
zero displayed milliseconds. Before song 003 returned a report, the Dart
product tracker stopped with:

```text
Bad state: noteOff releases note 69, which is not pressed
```

The command exited 1. It did not write a summary, review, or manifest. The
partial directory is retained unchanged with one file:

| Artifact              | SHA-256                                                            |     Bytes |
| --------------------- | ------------------------------------------------------------------ | --------: |
| Song 002 piece report | `a09a183a7b11dba36c35ded81e696e45007811c06c7031407ffafed2985cf4d0` | 1,650,976 |
| Song 002 MIDI         | `5c6d62a8bbace19b95e01964cf0dfbe0219111478fa4e08c10a505af50a77e62` |         - |
| Song 003 MIDI         | `22e913530ff39f9c3702758f6353b027f1f6197d7c06f79df8a34347762b4c1d` |         - |

Inspection of the already-opened error path showed that the shared historical
normalizer adds an unmatched released note to its sustained set while pedal is
down. The current app's `midiTemporalEventsProvider` explicitly returns without
emitting when a note-off cannot remove a pressed note. Consequently production
does not send this invalid event to `PolychordOnsetTracker`; the abort is a
replay defect, not a demonstrated app crash or musical false display.

**Plain-English reading.** The held run did not find a bad polychord. It found
that the test harness handled a malformed or redundant MIDI release differently
from the app. One song completed with no annotation, and the next stopped before
producing an answer.

**Decisions.** The v2 run is an aborted technical result, neither a pass nor a
product failure. Do not delete, overwrite, or rerun v2. Treat the reserve as no
longer pristine and disclose that song 002's negative output and song 003's
input error were observed. Correct only replay normalization, with no musical
policy changes, before any completion run.

**Next.** Prospectively freeze the app-equivalent v3 normalization and its
controls in a separate entry. After committing that boundary, run all 808 songs
once into a new v3 directory and interpret it with the disclosed deviation.
