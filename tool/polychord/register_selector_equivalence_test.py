"""Controls for the Python/Dart polychord equivalence harness."""

from __future__ import annotations

import unittest

import register_selector
import register_selector_equivalence as subject


class RegisterSelectorEquivalenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = list(subject.conformance_cases())

    def test_reuses_the_complete_pinned_conformance_input_surface(self) -> None:
        core = [case for case in self.cases if case["kind"] == "core"]
        focused = [case for case in self.cases if case["kind"] == "focused"]

        self.assertEqual(len(core), 3300)
        self.assertEqual(len(focused), 11)
        self.assertEqual(len({case["id"] for case in self.cases}), 3311)

    def test_compares_every_preregistered_profile(self) -> None:
        self.assertEqual(
            subject.SELECTOR_IDS,
            tuple(register_selector.SELECTOR_PROFILES),
        )
        self.assertEqual(len(subject.SELECTOR_IDS), 4)

    def test_outcome_requires_selection_or_one_abstention_reason(self) -> None:
        selected = register_selector.decision_document([48, 52, 55, 66, 70, 73])
        abstained = register_selector.decision_document([60, 64, 67])

        self.assertEqual(subject._decision_outcome(selected), "selected")
        self.assertEqual(
            subject._decision_outcome(abstained), "no-structural-candidate"
        )


if __name__ == "__main__":
    unittest.main()
