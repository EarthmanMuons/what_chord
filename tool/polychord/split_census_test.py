"""Unit tests for split_census.py using synthetic, non-corpus voicings."""

from __future__ import annotations

import unittest

import split_census as subject


class SplitCensusTest(unittest.TestCase):
    def test_primary_profile_is_symmetric_and_uses_complete_common_chords(
        self,
    ) -> None:
        profile = subject.TEMPLATE_PROFILES["complete-common"]

        self.assertEqual(profile["upper"], profile["lower"])
        self.assertEqual(
            set(profile["upper"].values()),
            {"major", "minor", "dominant7", "major7", "minor7"},
        )

    def test_bichord_profile_is_the_symmetric_two_triad_ablation(self) -> None:
        profile = subject.TEMPLATE_PROFILES["bichord-triads"]

        self.assertEqual(profile["upper"], profile["lower"])
        self.assertEqual(set(profile["upper"].values()), {"major", "minor"})

    def test_petrushka_fires_in_both_constructional_profiles(self) -> None:
        notes = [48, 52, 55, 66, 70, 73]

        for profile_name in ("bichord-triads", "complete-common"):
            with self.subTest(profile=profile_name):
                self.assertEqual(
                    [
                        subject.split_symbol(split)
                        for split in self.registral(notes, profile_name)
                    ],
                    ["F#|C"],
                )

    def test_augurs_requires_common_chords_not_bichord_triads(self) -> None:
        # E major below D#7, enharmonically Fb major below Eb7.
        notes = [28, 40, 44, 47, 51, 55, 58, 61]

        self.assertEqual(self.registral(notes, "bichord-triads"), [])
        splits = self.registral(notes, "complete-common")
        self.assertEqual([subject.split_symbol(split) for split in splits], ["D#7|E"])

    def test_lower_fragments_are_a_boundary_profile_not_the_primary_profile(
        self,
    ) -> None:
        # D major over a C7 shell without its fifth.
        notes = [36, 52, 58, 62, 66, 69]

        self.assertEqual(self.registral(notes, "complete-common"), [])
        splits = self.registral(notes, "upper-structure-triads")
        self.assertEqual(
            [subject.split_symbol(split) for split in splits],
            ["D|C:seventhShellThird"],
        )

    def test_shared_pitch_class_is_allowed_only_with_separate_note_instances(
        self,
    ) -> None:
        # G minor below C major, with G sounded separately in both registers.
        notes = [43, 46, 50, 60, 64, 67]
        profile = subject.TEMPLATE_PROFILES["bichord-triads"]

        allowed = subject.registral_splits(
            notes,
            3,
            profile["upper"],
            profile["lower"],
            allow_shared_pitch_classes=True,
        )
        disallowed = subject.registral_splits(
            notes,
            3,
            profile["upper"],
            profile["lower"],
            allow_shared_pitch_classes=False,
        )
        covers = subject.pc_covers(
            notes,
            7,
            profile["upper"],
            profile["lower"],
            allow_shared_pitch_classes=True,
        )

        self.assertEqual([subject.split_symbol(split) for split in allowed], ["C|Gm"])
        self.assertEqual(allowed[0]["sharedPitchClasses"], [7])
        self.assertEqual(disallowed, [])
        self.assertTrue(
            any(
                cover["upperRoot"] == 0
                and cover["lowerRoot"] == 7
                and cover["sharedPitchClasses"] == [7]
                for cover in covers
            )
        )

        one_g = [43, 46, 50, 60, 64]
        self.assertFalse(
            any(
                cover["upperRoot"] == 0 and cover["lowerRoot"] == 7
                for cover in subject.pc_covers(
                    one_g,
                    7,
                    profile["upper"],
                    profile["lower"],
                    allow_shared_pitch_classes=True,
                )
            )
        )

    def test_same_root_in_two_registers_is_not_a_polychord_split(self) -> None:
        notes = [36, 40, 43, 60, 64, 67]

        self.assertEqual(self.registral(notes, "bichord-triads"), [])

    def test_every_qualifying_registral_split_is_reported(self) -> None:
        # C major | B minor7 and Cmaj7 | D major are both exact decompositions.
        notes = [36, 40, 43, 59, 74, 78, 81]

        splits = self.registral(notes, "complete-common")

        self.assertEqual(
            {subject.split_symbol(split) for split in splits},
            {"Bm7|C", "D|Cmaj7"},
        )

    def registral(self, notes: list[int], profile_name: str) -> list[dict]:
        profile = subject.TEMPLATE_PROFILES[profile_name]
        return subject.registral_splits(
            notes,
            3,
            profile["upper"],
            profile["lower"],
            allow_shared_pitch_classes=True,
        )


if __name__ == "__main__":
    unittest.main()
