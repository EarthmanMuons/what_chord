# 2026-08-01: Recenter and shorten the manuscript

**Goal.** Make the revised paper tell its scientific story before introducing
the experimental vocabulary, and remove secondary investigations that obscure
the controlled reference-definition result.

**Starting point.** The fresh-submission cleanup in entry 2026-08-01-15 left a
10-page manuscript with 7,261 words under conservative PDF text extraction. It
was scientifically scoped but opened with the streaming protocol and introduced
terms such as causal inference, selective prediction, reference construct, and
tonal ontology before giving a reader a concrete reason to care.

**Narrative decision.** The article now opens with a familiar musical situation:
an analyst may identify a temporary key while the written key signature remains
unchanged. A responsive detector and a stable detector can therefore both be
musically intelligible while receiving opposite benchmark scores. The
introduction then states the controlled question in plain language: if the
performed input and predictions stay fixed, can changing the documented
reference definition change which detector wins?

The abstract and introduction were rewritten around that sequence. Historical
in-time work now appears in Related Work, where it establishes precedent rather
than competing with the main question. “Frozen package” was replaced in most
reader-facing prose by “fixed configuration,” and “ontology” or “construct” was
replaced by “answer space,” “representation,” or “reference definition” where
the less specialized wording is equally precise. The model section likewise
explains recency weighting and key profiles before naming HMM machinery.

**Scope decision.** The main article retains the evidence needed for its central
argument:

- the same-performance, fixed-output dual-reference comparison;
- the exploratory memory-by-function grid;
- the descriptive reference-persistence analysis;
- the abstention operating curve;
- the predeclared held-out configuration reversal; and
- the qualified offline whole-piece reference points.

The standalone mode-disambiguation and adaptive-temporal-model sections were
removed. The progression, duration, and recognizer-confidence ablation summary,
the held-out error-mixture aside, and the posterior-calibration aside were also
removed. These results remain valid research artifacts with dated provenance;
they are not needed to establish the paper's revised contribution and may be
considered later for supplementary material. Removing them does not change a
detector output, reference label, result, uncertainty interval, analysis status,
or conclusion retained in the paper.

The offline table remains because it gives readers a familiar scale, but its
text now emphasizes that the systems receive different information and produce
different output forms. It supports no parity, superiority, or
live-applicability claim.

**Verification.** The manuscript was rebuilt and inspected with:

```sh
mise research:whatkey-paper
pdfinfo research/whatkey/paper/main.pdf
pdftotext research/whatkey/paper/main.pdf - | wc -w
pdftoppm -png -r 110 research/whatkey/paper/main.pdf \
  tmp/pdfs/whatkey-narrative
git diff --check
```

The resulting PDF is 8 pages and contains 5,422 extracted words, including the
reference list. The abstract is 203 source words. All eight rendered pages were
visually inspected; figures, tables, captions, columns, section transitions,
page numbers, and bibliography entries render without clipping or overlap.

**Interpretation.** This is a change in presentation and manuscript scope, not a
new analysis. The shorter paper gives the controlled experiment priority and
leaves room for the author to restore explanation selectively during a complete
read-through. The research log remains the record for secondary results that no
longer belong in the main narrative.

**Next.** Read the manuscript as a self-contained article, first for conceptual
continuity and then for sentence-level voice. Decide after that read whether any
removed result merits a supplement; do not restore material merely because it
already exists.
