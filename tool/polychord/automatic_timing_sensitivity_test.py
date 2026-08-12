"""Focused tests for the preregistered polychord timing comparison."""

from __future__ import annotations

import copy
import unittest

import automatic_timing_sensitivity as subject
import onset_support


def candidate() -> dict:
    return {
        "splitAfterIndex": 2,
        "lowerTopMidi": 55,
        "upperBottomMidi": 67,
        "gapSemitones": 12,
        "lower": {
            "rootPc": 0,
            "quality": "major",
            "midiNotes": [48, 52, 55],
            "pitchClasses": [0, 4, 7],
        },
        "upper": {
            "rootPc": 7,
            "quality": "minor",
            "midiNotes": [67, 70, 74],
            "pitchClasses": [2, 7, 10],
        },
        "sharedPitchClasses": [7],
        "symbol": "Gm|C",
    }


def source_item(separation_ms: int, *, event_offset: int = 0) -> dict:
    evidence = copy.deepcopy(subject.synthetic_evidence(separation_ms))
    for layer_name in ("lower", "upper"):
        for note in evidence[layer_name]["notes"]:
            note["onsetEventIndex"] += event_offset
    return {"candidate": candidate(), "onsetEvidence": evidence}


def interpreted_item(
    separation_ms: int, *, event_offset: int = 0, source_id: str = "synthetic/0"
) -> dict:
    item = source_item(separation_ms, event_offset=event_offset)
    return {
        "sourceInstanceId": source_id,
        "candidate": item["candidate"],
        "soundingInstanceBinding": subject.sounding_instance_binding(item),
        "profileInterpretations": {
            subject.profile_id(gap): subject.interpret_onset_evidence(
                item["onsetEvidence"], gap
            )
            for gap in subject.ONSET_GAP_MINIMUMS_MS
        },
    }


def frame(
    event_index: int,
    timestamp_ms: int,
    dwell_ms: int,
    item: dict,
) -> dict:
    return {
        "afterEventIndex": event_index,
        "timestampMs": timestamp_ms,
        "dwellMs": dwell_ms,
        "candidateInterpretations": [item],
    }


class AutomaticTimingSensitivityTest(unittest.TestCase):
    def test_profile_family_and_committed_baseline_id_are_fixed(self) -> None:
        self.assertEqual(subject.ONSET_GAP_MINIMUMS_MS, (50, 80, 100, 200, 300))
        self.assertEqual(subject.APPEARANCE_DWELLS_MS, (0, 50, 100, 200, 300))
        self.assertEqual(subject.profile_id(200), onset_support.ABLATION_ID)
        self.assertEqual(
            subject.profile_id(80),
            "coherent-separated-onsets-50-80ms/sensitivity-1",
        )
        self.assertEqual(subject.dwell_profile(200)["id"], "polychord-output/2")
        self.assertEqual(
            subject.dwell_profile(50)["id"],
            "authorization-dwell-50ms/sensitivity-1",
        )

    def test_every_onset_boundary_is_inclusive(self) -> None:
        for gap in subject.ONSET_GAP_MINIMUMS_MS:
            with self.subTest(gap=gap, role="exact"):
                exact = subject.interpret_onset_evidence(
                    subject.synthetic_evidence(gap), gap
                )
                self.assertEqual(exact["onsetCohortSupport"], "positive")
            with self.subTest(gap=gap, role="below"):
                below = subject.interpret_onset_evidence(
                    subject.synthetic_evidence(gap - 1), gap
                )
                self.assertEqual(below["onsetCohortSupport"], "neutral")
                self.assertIn(
                    "between-layer-separation-below-minimum",
                    below["reasonCodes"],
                )

    def test_200ms_profile_exactly_matches_committed_interpreter(self) -> None:
        cases = [
            subject.synthetic_evidence(0),
            subject.synthetic_evidence(200),
            subject.synthetic_evidence(400),
        ]
        incoherent = subject.synthetic_evidence(400)
        incoherent["lower"]["latestKnownOnsetMs"] = 51
        incoherent["lower"]["knownOnsetSpanMs"] = 51
        cases.append(incoherent)
        incomplete = subject.synthetic_evidence(400)
        incomplete["allCandidateOnsetsKnown"] = False
        cases.append(incomplete)

        for evidence in cases:
            with self.subTest(evidence=evidence):
                self.assertEqual(
                    subject.interpret_onset_evidence(evidence, 200),
                    onset_support.interpret_onset_evidence(evidence),
                )

    def test_orientation_is_neutral_but_signed_gap_retains_order(self) -> None:
        lower_first = subject.synthetic_evidence(80)
        upper_first = copy.deepcopy(lower_first)
        for note in upper_first["lower"]["notes"]:
            note["onsetTimestampMs"] = 80
        for note in upper_first["upper"]["notes"]:
            note["onsetTimestampMs"] = 0
        upper_first["lower"].update(
            {
                "distinctKnownOnsetTimestampsMs": [80],
                "earliestKnownOnsetMs": 80,
                "latestKnownOnsetMs": 80,
            }
        )
        upper_first["upper"].update(
            {
                "distinctKnownOnsetTimestampsMs": [0],
                "earliestKnownOnsetMs": 0,
                "latestKnownOnsetMs": 0,
            }
        )

        self.assertEqual(subject.signed_interval_gap_ms(lower_first), 80)
        self.assertEqual(subject.signed_interval_gap_ms(upper_first), -80)
        self.assertEqual(
            subject.interpret_onset_evidence(upper_first, 80)["onsetCohortSupport"],
            "positive",
        )

    def test_sounding_binding_changes_on_reattack(self) -> None:
        first = source_item(80)
        reattack = source_item(80, event_offset=10)

        self.assertNotEqual(
            subject.serialized_opportunity_key(first),
            subject.serialized_opportunity_key(reattack),
        )

    def test_episode_accumulates_only_consecutive_equal_bindings(self) -> None:
        profile = subject.profile_id(50)
        same = interpreted_item(80)
        rows = [
            frame(10, 100, 30, same),
            frame(11, 130, 20, same),
            frame(13, 200, 40, same),
        ]

        episodes = subject.authorization_episodes(rows, profile)

        self.assertEqual([episode["durationMs"] for episode in episodes], [50, 40])
        self.assertEqual(
            [len(episode["frames"]) for episode in episodes],
            [2, 1],
        )

    def test_reattack_splits_an_episode_on_consecutive_frames(self) -> None:
        profile = subject.profile_id(50)
        rows = [
            frame(10, 100, 30, interpreted_item(80)),
            frame(
                11,
                130,
                20,
                interpreted_item(80, event_offset=10, source_id="synthetic/1"),
            ),
        ]

        episodes = subject.authorization_episodes(rows, profile)

        self.assertEqual([episode["durationMs"] for episode in episodes], [30, 20])

    def test_neutral_frame_ends_an_episode(self) -> None:
        profile = subject.profile_id(80)
        rows = [
            frame(1, 0, 20, interpreted_item(80)),
            frame(2, 20, 10, interpreted_item(79, source_id="synthetic/1")),
            frame(3, 30, 20, interpreted_item(80, source_id="synthetic/2")),
        ]

        episodes = subject.authorization_episodes(rows, profile)

        self.assertEqual([episode["durationMs"] for episode in episodes], [20, 20])

    def test_every_dwell_boundary_is_inclusive(self) -> None:
        for dwell in subject.APPEARANCE_DWELLS_MS:
            with self.subTest(dwell=dwell, role="exact"):
                exact = subject.survival_by_dwell(dwell)[str(dwell)]
                self.assertTrue(exact["survives"])
                self.assertEqual(exact["potentialPostDwellDurationMs"], 0)
            if dwell:
                with self.subTest(dwell=dwell, role="below"):
                    below = subject.survival_by_dwell(dwell - 1)[str(dwell)]
                    self.assertFalse(below["survives"])
                    self.assertEqual(below["potentialPostDwellDurationMs"], 0)

    def test_zero_duration_episode_survives_only_zero_dwell(self) -> None:
        episode = subject.authorization_episodes(
            [frame(0, 0, 0, interpreted_item(50))],
            subject.profile_id(50),
        )[0]

        self.assertEqual(episode["durationMs"], 0)
        self.assertTrue(episode["survivalByAppearanceDwellMs"]["0"]["survives"])
        for dwell in (50, 100, 200, 300):
            self.assertFalse(
                episode["survivalByAppearanceDwellMs"][str(dwell)]["survives"]
            )

    def test_survival_summary_keeps_opportunity_time_distinct(self) -> None:
        episodes = [
            {"survivalByAppearanceDwellMs": subject.survival_by_dwell(duration)}
            for duration in (100, 200)
        ]

        summary = subject.summarize_episode_survival(episodes)

        self.assertEqual(summary["50"]["survivingOpportunities"], 2)
        self.assertEqual(summary["50"]["sumOfPerOpportunityPotentialPostDwellMs"], 200)
        self.assertIn("not merged", summary["50"]["durationInterpretation"])

    def test_monotonicity_guards_accept_the_registered_order(self) -> None:
        item = interpreted_item(100)
        rows = [frame(0, 0, 300, item)]
        subject.assert_onset_monotonicity(rows)
        episodes = subject.authorization_episodes(rows, subject.profile_id(50))
        subject.assert_dwell_monotonicity(episodes)

    def test_mechanics_controls_are_excluded_and_complete(self) -> None:
        controls = subject.mechanics_controls()

        self.assertTrue(controls["excludedFromSourceAndCorpusTotals"])
        self.assertEqual(len(controls["onsetBoundaryControls"]), 10)
        self.assertEqual(len(controls["dwellBoundaryControls"]), 9)
        self.assertEqual(len(controls["matchedHistoryControls"]), 2)


if __name__ == "__main__":
    unittest.main()
