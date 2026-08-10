# 2026-08-10: Adopt framework v0 and defer the annotation pilot

**Goal.** Decide whether the six-case independent-review pilot supplies evidence
strong enough to remain a prerequisite for the polychord framework, and record a
scientifically honest path if it does not.

**Setup.** Base repository commit `7c608365`. The worktree was clean. No pilot
response had been collected, received, inspected, or committed. The two score
crops, the generated-case presentation, the private initial case descriptions,
and the reviewer guide were inspected together. The historical artifacts were
pinned before changing the active research policy:

```sh
git status --short
shasum -a 256 \
  research/polychord/pilot-ruler-v0.json \
  research/polychord/pilot-annotation.md \
  research/polychord/pilot-review-template-v0.json \
  research/polychord/review-instrument/index.html \
  research/polychord/review-instrument/app.mjs \
  research/polychord/review-instrument/model.mjs \
  research/polychord/review-instrument/presentation.mjs \
  research/polychord/review-instrument/assets/manifest.json \
  research/polychord/review-instrument/assets/petrushka-r49.png \
  research/polychord/review-instrument/assets/augurs-r13.png
```

The resulting SHA-256 digests were:

- initial six-case ruler:
  `f5fa532757cba27ef21760920647d612a7cba0f91b921993a4f0c9e7ca35f5c3`;
- reviewer guide:
  `fbd45bb7858bfb25c1ae2a7cdfe19ae6eb46a740b75622a98f6edbe6bb514dbd`;
- neutral review packet:
  `1817a75b0b2a59e6a736ae7c84f10d3010564e3ec495959d16ff89f00af3cbe5`;
- instrument HTML:
  `e948390c3e1974ae5dae8e70b4553e64a3b7d5687cbc874ceed45eb7bbc25b9d`;
- browser controller:
  `6b65b4ad62d33232cdd9888aff2699abfda66af103cbf9d230f501760515d3bf`;
- pure response model:
  `bbeebcf3b24c3800881bf25e16933cf60572894b38740028c8c9f9b1c9578dc8`;
- presentation model:
  `493902dcb407564777ab80463b11d9d533fe6f934e66682b6e83307eb102ea60`;
- presentation manifest:
  `a77bcab355ddeafde6804353235834c2e820164256c7a5fce0c7cfcd44cdeb6b`;
- Petrushka crop:
  `5b7f59dbfb9757253305c6743a4d24c99109b86c76517d545d54d7c678e8e184`;
- Augurs crop:
  `d552b39f1f9d19c6904674f5d8bb756c376784ebec561f3af9be257d4893405e`.

**What happened.** The review exposed a structural problem with the study rather
than a remaining interface defect.

The Petrushka crop presents a dense orchestral passage while the initial answer
depends on the two clarinet streams. Leaving those streams unidentified makes
the requested focus unclear; identifying or highlighting them substantially
reveals the proposed decomposition. The case cannot simultaneously be
initial-label-blinded, self-explanatory, and an open discovery task in its
current form.

The Augurs crop is clearer, but its notated hand and voice organization contains
construction evidence that a pitch-and-register analyzer does not receive. A
single response would therefore mix score interpretation with judgment about a
different machine-input condition.

The two matched synthetic temporal controls retain only an aggregate note set
and attack cohorts in the neutral packet. The private generation recipe says
which notes are held, but the reviewer is not shown note-off events, pressed
versus sustained state, pedal state, or frame-by-frame observations. An onset
list cannot establish the intended event window or reliably distinguish a
layered sonority from arpeggiation or sequential harmony. Simultaneous onset may
favor integration, but it does not prove the private C9 label either.

Finally, one form asks the reviewer to choose the musical unit, classify the
construction, reconstruct layers, and judge three input conditions. A
disagreement would not isolate whether the construct, evidence, representation,
or instructions failed. More reviewers would make that ambiguity more precise,
not remove it.

The prior-art record already supports a narrower theory-derived foundation:
polychord is a constructional or notational term rather than a claim about two
heard keys; complete chordal grouping is central; canonical constructions can
fuse perceptually; upper structures and integrated extensions are required
boundaries; and register, onset, release, pedal, and motion are distinct
evidence conditions. Those sources can ground a transparent product hypothesis
without pretending that the hypothesis is independent ground truth.

**Plain-English reading.** The form could have collected opinions, but its
answers would not tell us cleanly whether musicians disagreed about polychords
or were simply looking at incomplete or unclear evidence. We do not need outside
permission to write down a conservative product definition supported by the
literature. We do need outside reviewers later if we want to claim that other
people can reproduce our labels or that an accuracy number generalizes beyond
our own specification.

**Decisions.** Defer the six-case pilot before distribution and collect no
responses with instrument version 2. Preserve the pinned ruler, guide, packet,
instrument, and images unchanged as historical provenance. The pilot is a
documented negative design result, not an unfinished gate.

Adopt `FRAMEWORK.md` as the active theory-derived v0 specification:

- name a constructional or notational polychord, not keys or independent
  perceptual streams;
- support two layers initially and show the result only as a secondary
  annotation, leaving the primary single-chord identity unchanged;
- use a symmetric complete-common vocabulary: major and minor triads plus
  dominant, major, and minor seventh chords with different roots;
- permit shared pitch classes only when distinct sounded notes can be assigned
  to the layers;
- exclude bass-only, fifth-only, shell, upper-structure, same-root, and
  three-or-more-layer candidates from the initial positive generator;
- require contiguous register grouping as the generator baseline;
- treat noncontiguous assignments as research comparators and temporal cues as
  incremental evidence; and
- require complete note-on, note-off, pedal, pressed, sustained, and frame state
  for any temporal fixture used to evaluate those cues.

Use literature-attested construction, theory-derived boundary, synthetic
regression guard, and unresolved candidate as separate epistemic labels.
Maintainer-authored positive, boundary, and negative expectations may form an
internal product-policy suite, but results against it are not independent
accuracy.

External validation is optional for the active framework and engineering work.
It is mandatory before a reproducibility claim, an independently validated ruler
claim, or a generalized accuracy claim. Any later study must use a new
registered instrument that separates constructional appropriateness from input
recoverability and presents the exact musical or event evidence needed for each
question.

**Next.** Build the evidence foundation before a naming lever: define an exact
frame-replay fixture with note-on, note-off, pedal, pressed, and sustained
state; then implement the conservative register-only candidate generator against
synthetic regression guards. In parallel, promote score-verified candidates into
a provenance-rich internal suite using the framework's epistemic labels. Freeze
the full output contract, metrics, adoption threshold, and performance budget
before evaluating the generator as a product feature.
