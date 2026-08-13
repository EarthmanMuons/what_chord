"""Controls for the Python/Dart candidate-binding equivalence harness."""

from __future__ import annotations

import copy
import unittest

import candidate_instance_binding_equivalence as subject


class CandidateInstanceBindingEquivalenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = subject.equivalence_cases()

    def test_replays_every_frame_from_the_pinned_manifest(self) -> None:
        fixture_cases = [case for case in self.cases if case["fixtureId"] is not None]
        synthetic_cases = [case for case in self.cases if case["fixtureId"] is None]

        self.assertEqual(len(self.cases), 125)
        self.assertEqual(len(fixture_cases), 124)
        self.assertEqual(len({case["fixtureId"] for case in fixture_cases}), 9)
        self.assertEqual(len(synthetic_cases), 1)
        self.assertEqual(len({case["id"] for case in self.cases}), 125)

    def test_expected_records_have_exact_complete_shape(self) -> None:
        records = [
            binding for case in self.cases for binding in case["candidateBindings"]
        ]

        self.assertEqual(len(records), 19)
        self.assertTrue(
            all(
                set(record)
                == {
                    "trackerEpoch",
                    "candidate",
                    "targetInstances",
                    "availability",
                }
                for record in records
            )
        )
        self.assertEqual(
            [record["availability"] for record in records].count("complete"),
            18,
        )
        self.assertEqual(
            [record["availability"] for record in records].count("incomplete"),
            1,
        )

    def test_python_adaptation_preserves_null_and_detects_reattack(self) -> None:
        source = next(
            binding for case in self.cases for binding in case["candidateBindings"]
        )
        incomplete_item = {
            "candidate": source["candidate"],
            "soundingInstanceBinding": {
                "lower": copy.deepcopy(source["targetInstances"][:3]),
                "upper": copy.deepcopy(source["targetInstances"][3:]),
            },
        }
        incomplete_item["soundingInstanceBinding"]["lower"][0]["onsetEventIndex"] = None
        reattacked_item = copy.deepcopy(incomplete_item)
        reattacked_item["soundingInstanceBinding"]["lower"][0]["onsetEventIndex"] = 900

        incomplete = subject.binding_from_python_opportunity(incomplete_item, 0)
        reattacked = subject.binding_from_python_opportunity(reattacked_item, 0)

        self.assertEqual(incomplete["availability"], "incomplete")
        self.assertNotEqual(incomplete, reattacked)
        self.assertEqual(reattacked["availability"], "complete")


if __name__ == "__main__":
    unittest.main()
