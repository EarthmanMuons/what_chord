# 2026-08-01: Make the manuscript stand alone as a fresh submission

**Goal.** Decide which chronology belongs in the resubmitted manuscript and
which belongs in the cover letter, response matrix, or research log. The journal
declined the first submission at editorial screening while explicitly inviting a
new submission, so the paper should read as a complete scientific article, not
as an annotated record of the revision process.

**Setup.** The prose pass followed the structural revision in entry
2026-08-01-12 and the reference-temporal correction in entries 2026-08-01-13 and
2026-08-01-14. No detector output, reference label, analysis artifact, result,
or citation was changed. The manuscript was rebuilt with:

```sh
mise research:whatkey-paper
pdftotext research/whatkey/paper/main.pdf - | wc -w
pdfinfo research/whatkey/paper/main.pdf
```

**What happened.** The manuscript had accumulated several kinds of provenance
that are important to preserve but distracting inside a fresh submission:

- references to editorial screening, revision analyses, and numbered internal
  analyses R1-R4;
- the chronology and size of the ASAP/When-in-Rome alignment correction;
- comparisons between paper-era and current application defaults;
- later product use of held-out pieces and later product mechanisms; and
- wording tied specifically to the manuscript the editors first saw, such as
  "submitted contrast."

Those passages were removed or rewritten around the final method. The paper now
states the content-based measure-offset calibration without narrating the bug it
replaced, describes the final scorable cohorts without a correction history, and
limits secondary-ablation claims to the mechanisms actually tested.

Two kinds of chronology remain because they affect evidential interpretation:

1. the held-out package comparison was specified before its single test
   execution; and
2. the dual-reference, segment-persistence, and 2x2 analyses were designed after
   inspection of the original cross-corpus pattern and are exploratory or
   descriptive.

Fixed splits, configurations, claim streams, and result artifacts also remain
identified as fixed or frozen because that is reproducibility information, not
journal-process history.

The resulting PDF is 10 pages. Conservative text extraction gives 7,261 words,
within TISMIR's 8,000-word limit but still leaving compression as a worthwhile
later pass.

**Plain-English reading.** A reader needs to know which analyses were planned
before seeing test results and which were designed later. They do not need a
running account of what the editors said, which software defaults changed after
submission, or how a pre-review alignment bug was discovered. The first kind of
history stays because it changes how strongly evidence should be read; the
second moves to records designed for that purpose.

**Decisions.** Use the manuscript for final methods, results, analysis status,
and limitations. Reserve the resubmission cover letter and editorial response
for prior submission 439, the invitation to resubmit, how each editorial point
was addressed, and the 347-label alignment correction. Preserve complete
chronology, commands, hashes, and old/new values in the dated research log and
scratch response matrix.

**Next.** Have the author read the complete paper as an article. After that
read, decide which secondary material to cut, compress, or move to a supplement;
then perform citation-style and final layout work.
