#!/usr/bin/env python3
"""Freeze the performed-input identity split for an ASAP x When in Rome set.

The split unit is the SONATA: all 32 Beethoven sonata numbers are ranked by a
stable seeded hash and the top test-ratio share is held out, so every movement
and every performance of a work lands on one side, and the side of a movement
that later passes the alignment gate (a rescue) is already determined by its
sonata rather than decided after looking at results. Gate-failing movements
are recorded with their exclusion reason but carry no split side until they
pass.

The split file records identifiers, counts, hashes, and the gate roster only
(facts, not corpus content), so it is committable while the fixtures stay
license-gated under build/ (research/whatkey/data/NOTICE.md).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SPLIT_SCHEMA = "performed-input-split/1"
DEFAULT_SEED = "performed-input-asap-wir-nc-v2-split-2026-07-27"

# Movements excluded by the alignment census gate (performed-input logs
# 2026-07-27-02 and -04): the shift response must peak sharply at zero.
GATE_EXCLUDED = {
    "7-1": "sectional drift (two offset regimes, ending-convention mismatch)",
    "7-4": "sectional drift (two offset regimes, ending-convention mismatch)",
    "12-1": "sectional drift plus late-variation texture",
    "31-3_4": "two movements in one folder; no offset fits",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fixtures-manifest",
        type=Path,
        default=Path("build/whatkey-fixtures/asap-wir-nc-v2/manifest.json"),
    )
    parser.add_argument("--out", type=Path)
    parser.add_argument("--seed", default=DEFAULT_SEED)
    parser.add_argument("--test-ratio", type=float, default=0.3)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    manifest = json.loads(args.fixtures_manifest.read_text())
    set_name = manifest["set"]
    out = (
        args.out or REPO_ROOT / f"research/performed-input/data/splits/{set_name}.json"
    )
    out.parent.mkdir(parents=True, exist_ok=True)

    ranked = sorted(
        range(1, 33),
        key=lambda n: hashlib.sha256(f"{args.seed}|sonata-{n}".encode()).hexdigest(),
    )
    test_sonatas = set(ranked[: round(32 * args.test_ratio)])
    sonata_side = {
        n: "test" if n in test_sonatas else "development" for n in range(1, 33)
    }

    sides: dict[str, list[dict]] = {"development": [], "test": []}
    excluded = []
    for fixture in manifest["fixtures"]:
        name = fixture["id"].split("/")[-1]
        sonata = int(re.match(r"^(\d+)", name).group(1))
        row = {
            "id": fixture["id"],
            "title": fixture["title"],
            "sonata": sonata,
            "events": fixture["events"],
            "sha256": fixture["sha256"],
        }
        if name in GATE_EXCLUDED:
            excluded.append({**row, "reason": GATE_EXCLUDED[name]})
        else:
            sides[sonata_side[sonata]].append(row)

    split = {
        "schema": SPLIT_SCHEMA,
        "set": set_name,
        "frozenAt": datetime.now(tz=timezone.utc).date().isoformat(),
        "protocol": "research/performed-input/PROTOCOL.md",
        "source": {
            "type": manifest["source"]["type"],
            **{
                key: value
                for key, value in manifest["source"].items()
                if key.endswith("Commit")
            },
            "fixtureManifest": str(args.fixtures_manifest),
            "fixtureContentHash": manifest["contentHash"]["value"],
            "license": manifest["source"]["license"],
        },
        "method": {
            "seed": args.seed,
            "testRatio": args.test_ratio,
            "selection": (
                "All 32 sonata numbers ranked by SHA-256 of seed plus "
                "sonata; the top testRatio share is held out. Movements "
                "inherit their sonata's side, including any movement that "
                "later passes the alignment gate."
            ),
            "gate": (
                "wir_alignment_probe.py shift response must peak sharply at "
                "zero (performed-input logs 2026-07-27-02 and -04)."
            ),
        },
        "sonataSides": {str(n): sonata_side[n] for n in range(1, 33)},
        "counts": {
            side: {
                "movements": len(rows),
                "events": sum(r["events"] for r in rows),
            }
            for side, rows in sides.items()
        },
        "splits": {
            side: sorted(rows, key=lambda r: r["id"]) for side, rows in sides.items()
        },
        "gateExcluded": sorted(excluded, key=lambda r: r["id"]),
    }
    out.write_text(json.dumps(split, indent=1, sort_keys=True) + "\n")
    dev, test = split["counts"]["development"], split["counts"]["test"]
    total = dev["events"] + test["events"]
    print(
        f"development {dev['movements']} movements / {dev['events']} events "
        f"({dev['events'] / total:.0%}), test {test['movements']} / "
        f"{test['events']} ({test['events'] / total:.0%}), "
        f"{len(excluded)} gate-excluded -> {out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
