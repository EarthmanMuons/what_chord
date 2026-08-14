"""Verify and summarize retained polychord product and prior-art results."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import prior_art_baseline_comparison as comparison
import prior_art_baselines
import product_suite_scorer

SUMMARY_SCHEMA = "polychord-product-comparison-summary/1"
MANIFEST_SCHEMA = "polychord-product-comparison-result-manifest/1"
REPO_ROOT = Path(__file__).parents[2]
RESULT_ROOT = Path("research/polychord/results/product-comparison-v1")
PRIOR_ART_PATH = RESULT_ROOT / "prior-art-comparison-v1.json"
PRODUCT_PREDICTIONS_PATH = RESULT_ROOT / "product-predictions-v1.json"
PRODUCT_SCORE_PATH = RESULT_ROOT / "product-score-v1.json"
SUMMARY_PATH = RESULT_ROOT / "comparison-summary-v1.json"
MANIFEST_PATH = RESULT_ROOT / "result-manifest-v1.json"
SUITE_PATH = Path("research/polychord/data/product-suite/suite-v0.json")


def _load(path: Path) -> dict:
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise TypeError(f"{path} must contain an object")
    return value


def _sum_strata(summary: dict, field: str, child: str | None = None) -> int:
    if child is None:
        return sum(value[field] for value in summary.values())
    return sum(value[field][child] for value in summary.values())


def _validate_result(
    result: dict,
    *,
    baseline_id: str,
    observation: dict,
) -> None:
    prior_art_baselines.validate_result(result)
    if result["baseline"]["id"] != baseline_id:
        raise ValueError("retained result baseline ID differs")
    if result["observationId"] != observation["observationId"]:
        raise ValueError("retained result observation ID differs")
    if result["inputSha256"] != prior_art_baselines.sha256_json(observation):
        raise ValueError("retained result neutral-input digest differs")


def _validate_provenance(report: dict) -> None:
    provenance = report["provenance"]
    if provenance["sourceTreeCleanAtStart"] is not True:
        raise ValueError("baseline comparison did not start from a clean tree")
    if len(provenance["sourceCommit"]) != 40:
        raise ValueError("baseline comparison source commit is invalid")
    for name in (
        "suite",
        "contract",
        "adapterFreeze",
        "comparisonFreeze",
        "runtimeManifest",
        "runner",
    ):
        pin = provenance[name]
        path = REPO_ROOT / pin["path"]
        if name == "runtimeManifest" and not path.exists():
            # The build manifest contains machine-local executable paths and is
            # intentionally not tracked. Its digest remains in the retained
            # report and is checked whenever that local build artifact exists.
            continue
        if comparison.sha256_file(path) != pin["sha256"]:
            raise ValueError(f"baseline comparison {name} digest differs")


def validate_prior_art(report: dict) -> dict:
    if set(report) != {"schema", "provenance", "inputSummary", "baselines"}:
        raise ValueError("prior-art comparison fields are invalid")
    if report["schema"] != comparison.COMPARISON_SCHEMA:
        raise ValueError("prior-art comparison schema is invalid")
    _validate_provenance(report)
    prepared = comparison.prepare_inputs(REPO_ROOT / SUITE_PATH)
    expected_input_summary = {
        "namedTargetCount": len(prepared["namedTargets"]),
        "namedInvocationCount": sum(
            target["observation"] is not None for target in prepared["namedTargets"]
        ),
        "streamCount": len(prepared["streamTargets"]),
        "changedSoundingFrameCount": sum(
            len(stream["frames"]) for stream in prepared["streamTargets"]
        ),
        "adapterObservationCount": len(prepared["adapterObservations"]),
    }
    if report["inputSummary"] != expected_input_summary:
        raise ValueError("prior-art comparison input summary differs")
    if [value["baselineId"] for value in report["baselines"]] != list(
        prior_art_baselines.BASELINE_IDS
    ):
        raise ValueError("prior-art comparison baseline order differs")

    expected_ids = {
        observation["observationId"] for observation in prepared["adapterObservations"]
    }
    for baseline in report["baselines"]:
        baseline_id = baseline["baselineId"]
        if set(baseline) != {"baselineId", "namedSnapshots", "adaptedStreams"}:
            raise ValueError(f"{baseline_id} comparison fields are invalid")
        named_values = baseline["namedSnapshots"]["targets"]
        if len(named_values) != len(prepared["namedTargets"]):
            raise ValueError(f"{baseline_id} named-target count differs")
        results = {}
        for expected, actual in zip(prepared["namedTargets"], named_values):
            retained_target = {
                key: value for key, value in actual.items() if key != "evaluation"
            }
            if retained_target != expected:
                raise ValueError(f"{baseline_id} retained named target differs")
            result = actual["evaluation"]["result"]
            if expected["observation"] is not None:
                _validate_result(
                    result,
                    baseline_id=baseline_id,
                    observation=expected["observation"],
                )
                if result["observationId"] in results:
                    raise ValueError(f"{baseline_id} repeats a result")
                results[result["observationId"]] = result
            recalculated = comparison.evaluate_named_target(
                expected,
                result,
                baseline_id,
            )
            if actual["evaluation"] != recalculated:
                raise ValueError(f"{baseline_id} named evaluation differs")
        expected_named_summary = comparison.summarize_named(named_values)
        if baseline["namedSnapshots"]["summaryByStratum"] != expected_named_summary:
            raise ValueError(f"{baseline_id} named summary differs")

        stream_values = baseline["adaptedStreams"]["streams"]
        if len(stream_values) != len(prepared["streamTargets"]):
            raise ValueError(f"{baseline_id} stream count differs")
        for expected, actual in zip(prepared["streamTargets"], stream_values):
            if [frame["observationId"] for frame in actual["frames"]] != [
                frame["observationId"] for frame in expected["frames"]
            ]:
                raise ValueError(f"{baseline_id} stream frame order differs")
            for expected_frame, actual_frame in zip(
                expected["frames"], actual["frames"]
            ):
                retained_frame = {
                    key: value
                    for key, value in actual_frame.items()
                    if key
                    not in {
                        "rawOrderedCompositeIdentity",
                        "anyCompositeEmitted",
                        "result",
                    }
                }
                if retained_frame != expected_frame:
                    raise ValueError(f"{baseline_id} retained stream frame differs")
                result = actual_frame["result"]
                _validate_result(
                    result,
                    baseline_id=baseline_id,
                    observation=expected_frame["observation"],
                )
                if result["observationId"] in results:
                    raise ValueError(f"{baseline_id} repeats a result")
                results[result["observationId"]] = result
            recalculated = comparison.evaluate_stream(expected, results)
            if actual != recalculated:
                raise ValueError(f"{baseline_id} stream evaluation differs")
        if set(results) != expected_ids:
            raise ValueError(f"{baseline_id} result coverage differs")
        expected_stream_summary = comparison.summarize_streams(stream_values)
        if baseline["adaptedStreams"]["summary"] != expected_stream_summary:
            raise ValueError(f"{baseline_id} stream summary differs")
        if baseline["adaptedStreams"]["evaluationWrapper"] != {
            "status": "not-run",
            "reason": (
                "Version 1 reports native static-detector frames; "
                "no common temporal wrapper was preregistered."
            ),
        }:
            raise ValueError(f"{baseline_id} wrapper record differs")
    return prepared


def validate_product(predictions_path: Path, score: dict) -> None:
    rescored = product_suite_scorer.score(REPO_ROOT / SUITE_PATH, predictions_path)
    if score != rescored:
        raise ValueError("retained product score differs from independent rescoring")
    if score["suiteExactGatePass"] is not True:
        raise ValueError("retained product prediction does not pass the exact gate")


def summarize(report: dict, product_score: dict) -> dict:
    baselines = []
    for baseline in report["baselines"]:
        strata = baseline["namedSnapshots"]["summaryByStratum"]
        positive_exact = []
        positive_missed = []
        ordered_excluded = []
        guard_violations = []
        for target in baseline["namedSnapshots"]["targets"]:
            evaluation = target["evaluation"]
            if evaluation["status"] != "evaluated":
                continue
            metrics = evaluation["metrics"]
            if target["expectation"]["class"] == "positive":
                if metrics["orderedCompositeExact"] is True:
                    positive_exact.append(target["id"])
                elif metrics["orderedCompositeExact"] is False:
                    positive_missed.append(target["id"])
                else:
                    ordered_excluded.append(target["id"])
            elif metrics["correctCompositeAbstention"] is False:
                guard_violations.append(target["id"])
        status_counts = {
            status: sum(
                value["resultStatusCounts"][status] for value in strata.values()
            )
            for status in comparison.RESULT_STATUSES
        }
        baselines.append(
            {
                "baselineId": baseline["baselineId"],
                "namedSnapshots": {
                    "targetCount": _sum_strata(strata, "targetCount"),
                    "evaluatedTargetCount": _sum_strata(strata, "evaluatedTargetCount"),
                    "coverageExclusionCount": _sum_strata(
                        strata, "coverageExclusionCount"
                    ),
                    "compositeEmitted": {
                        "count": _sum_strata(strata, "compositeEmitted", "count"),
                        "eligible": _sum_strata(strata, "compositeEmitted", "eligible"),
                    },
                    "orderedCompositeExact": {
                        "count": _sum_strata(strata, "orderedCompositeExact", "count"),
                        "eligible": _sum_strata(
                            strata, "orderedCompositeExact", "eligible"
                        ),
                    },
                    "unorderedComponents": {
                        "matched": _sum_strata(
                            strata, "unorderedComponents", "matched"
                        ),
                        "eligible": _sum_strata(
                            strata, "unorderedComponents", "eligible"
                        ),
                    },
                    "assignmentExact": {
                        "count": _sum_strata(strata, "assignmentExact", "count"),
                        "eligible": _sum_strata(strata, "assignmentExact", "eligible"),
                    },
                    "guardAbstention": {
                        "count": _sum_strata(strata, "guardAbstention", "count"),
                        "eligible": _sum_strata(strata, "guardAbstention", "eligible"),
                    },
                    "failureCount": _sum_strata(strata, "failureCount"),
                    "resultStatusCounts": status_counts,
                    "positiveExactTargetIds": positive_exact,
                    "positiveMissedTargetIds": positive_missed,
                    "orderedCoverageExclusionTargetIds": ordered_excluded,
                    "guardViolationTargetIds": guard_violations,
                },
                "adaptedStreams": baseline["adaptedStreams"]["summary"],
            }
        )
    checkpoint_count = sum(
        len(result["checkpoints"]) for result in product_score["results"]
    )
    return {
        "schema": SUMMARY_SCHEMA,
        "authority": "derived-description-raw-case-level-results-are-authoritative",
        "inputSummary": report["inputSummary"],
        "product": {
            "producerId": product_score["producerId"],
            "scorerId": product_score["scorerId"],
            "suiteSha256": product_score["suiteSha256"],
            "checkpointCount": checkpoint_count,
            "suiteExactGatePass": product_score["suiteExactGatePass"],
            "summaryByStratum": product_score["summaryByStratum"],
        },
        "baselines": baselines,
    }


def validate_manifest(manifest_path: Path, summary: dict) -> dict:
    manifest = _load(manifest_path)
    if manifest.get("schema") != MANIFEST_SCHEMA:
        raise ValueError("result manifest schema is invalid")
    if manifest.get("status") != "retained-frozen-result":
        raise ValueError("result manifest status is invalid")
    for name, pin in manifest["artifacts"].items():
        path = REPO_ROOT / pin["path"]
        if comparison.sha256_file(path) != pin["sha256"]:
            raise ValueError(f"result manifest {name} digest differs")
    summary_pin = manifest["artifacts"]["derivedSummary"]
    if _load(REPO_ROOT / summary_pin["path"]) != summary:
        raise ValueError("retained derived summary differs")
    return manifest


def verify(
    *,
    prior_art_path: Path = REPO_ROOT / PRIOR_ART_PATH,
    predictions_path: Path = REPO_ROOT / PRODUCT_PREDICTIONS_PATH,
    score_path: Path = REPO_ROOT / PRODUCT_SCORE_PATH,
    manifest_path: Path | None = REPO_ROOT / MANIFEST_PATH,
) -> dict:
    report = _load(prior_art_path)
    product_score = _load(score_path)
    validate_prior_art(report)
    validate_product(predictions_path, product_score)
    result = summarize(report, product_score)
    if manifest_path is not None:
        validate_manifest(manifest_path, result)
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prior-art", type=Path, default=PRIOR_ART_PATH)
    parser.add_argument("--predictions", type=Path, default=PRODUCT_PREDICTIONS_PATH)
    parser.add_argument("--score", type=Path, default=PRODUCT_SCORE_PATH)
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--skip-manifest-check", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    summary = verify(
        prior_art_path=(REPO_ROOT / args.prior_art).resolve(),
        predictions_path=(REPO_ROOT / args.predictions).resolve(),
        score_path=(REPO_ROOT / args.score).resolve(),
        manifest_path=(
            None if args.skip_manifest_check else (REPO_ROOT / args.manifest).resolve()
        ),
    )
    serialized = json.dumps(summary, indent=2, sort_keys=True) + "\n"
    if args.out is None:
        print(serialized, end="")
    else:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(serialized)
        print(f"verified and wrote: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
