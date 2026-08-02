# Polychord pilot reviews

Completed independent-review packets are raw research data. Store each returned
packet as `pilot-v0-<opaque-annotator-id>.json`; use a pseudonymous identifier,
not a name or email. Do not edit a completed response after receipt. Corrections
use a new file with a provenance note in the next dated research log.

Validate a returned packet before analysis:

```sh
python3 tool/polychord/pilot_ruler.py research/polychord/pilot-ruler-v0.json \
  --validate-review research/polychord/reviews/pilot-v0-<opaque-annotator-id>.json
```

The template is generated from the pinned ruler and guide:

```sh
python3 tool/polychord/pilot_ruler.py research/polychord/pilot-ruler-v0.json \
  --review-packet-out research/polychord/pilot-review-template-v0.json
```

Do not commit a fabricated or same-author response to satisfy the protocol.
Agreement is calculated before adjudication and only after an independent,
validated packet is present.

Generate the predeclared agreement report before discussing disagreements:

```sh
python3 tool/polychord/pilot_agreement.py \
  research/polychord/pilot-ruler-v0.json \
  research/polychord/reviews/pilot-v0-<opaque-annotator-id>.json \
  --out build/polychord/pilot-v0-<opaque-annotator-id>-agreement.json
```

Record that exact command and the report digest in the dated log created when a
real review arrives. The report is pre-adjudication evidence; do not regenerate
it from adjudicated labels.
