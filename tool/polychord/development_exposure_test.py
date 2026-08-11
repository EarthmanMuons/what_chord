from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import decision_contract
import development_exposure as subject


class MidiNormalizationTest(unittest.TestCase):
    def test_mirrors_note_pedal_and_controller_123_state(self) -> None:
        messages = [
            subject.RawMidiMessage(0, "noteOn", midi_note=60, velocity=90),
            subject.RawMidiMessage(
                10,
                "controlChange",
                controller=subject.PEDAL_CONTROLLER,
                value=127,
            ),
            subject.RawMidiMessage(20, "noteOff", midi_note=60, velocity=0),
            subject.RawMidiMessage(20, "noteOff", midi_note=64, velocity=0),
            subject.RawMidiMessage(
                30,
                "controlChange",
                controller=subject.ALL_NOTES_OFF_CONTROLLER,
                value=0,
            ),
            subject.RawMidiMessage(
                40,
                "controlChange",
                controller=subject.PEDAL_CONTROLLER,
                value=0,
            ),
        ]

        result = subject.normalize_midi_messages(messages, 50)

        self.assertEqual(
            [frame["timestampMs"] for frame in result["frames"]],
            [0, 10, 20, 20, 30, 40],
        )
        self.assertEqual(result["frames"][2]["sustainedMidiNotes"], [60])
        self.assertEqual(result["frames"][3]["sustainedMidiNotes"], [60, 64])
        self.assertEqual(result["frames"][4]["soundingMidiNotes"], [])
        self.assertTrue(result["frames"][4]["pedalDown"])
        self.assertFalse(result["frames"][5]["pedalDown"])
        self.assertEqual(result["normalization"]["unmatchedNoteOffMessages"], 1)

    def test_counts_repeated_and_ignored_messages_without_frames(self) -> None:
        messages = [
            subject.RawMidiMessage(0, "noteOn", midi_note=60, velocity=90),
            subject.RawMidiMessage(1, "noteOn", midi_note=60, velocity=80),
            subject.RawMidiMessage(
                2,
                "controlChange",
                controller=subject.ALL_SOUND_OFF_CONTROLLER,
                value=0,
            ),
            subject.RawMidiMessage(
                3,
                "controlChange",
                controller=subject.PEDAL_CONTROLLER,
                value=0,
            ),
        ]
        result = subject.normalize_midi_messages(messages, 4)
        self.assertEqual(len(result["frames"]), 1)
        self.assertEqual(result["normalization"]["repeatedNoteOnMessages"], 1)
        self.assertEqual(result["normalization"]["ignoredAllSoundOffMessages"], 1)
        self.assertEqual(result["normalization"]["repeatedPedalMessages"], 1)
        self.assertEqual(result["normalization"]["noObservableChangeMessages"], 3)

    def test_rejects_decreasing_or_post_end_messages(self) -> None:
        with self.assertRaisesRegex(ValueError, "timestamps decrease"):
            subject.normalize_midi_messages(
                [
                    subject.RawMidiMessage(2, "noteOn", midi_note=60, velocity=90),
                    subject.RawMidiMessage(1, "noteOff", midi_note=60, velocity=0),
                ],
                3,
            )
        with self.assertRaisesRegex(ValueError, "after MIDI end"):
            subject.normalize_midi_messages(
                [subject.RawMidiMessage(2, "noteOn", midi_note=60, velocity=90)],
                1,
            )


class IsolationAndPresentationTest(unittest.TestCase):
    def test_output_must_be_new_child_of_build(self) -> None:
        with self.assertRaisesRegex(ValueError, "child of build"):
            subject.require_output_directory(Path("/tmp/polychord-result"))
        with self.assertRaisesRegex(ValueError, "child of build"):
            subject.require_output_directory(subject.BUILD_ROOT)
        with (
            tempfile.TemporaryDirectory(dir=subject.BUILD_ROOT) as existing,
            self.assertRaises(FileExistsError),
        ):
            subject.require_output_directory(Path(existing))

    def test_dart_payload_contains_observations_only(self) -> None:
        normalized = {
            "endTimestampMs": 300,
            "frames": [
                {
                    "afterEventIndex": 0,
                    "timestampMs": 0,
                    "pressedMidiNotes": [48, 52, 55, 62, 66, 69],
                    "sustainedMidiNotes": [],
                    "soundingMidiNotes": [48, 52, 55, 62, 66, 69],
                    "pedalDown": False,
                }
            ],
            "events": [{"labels": {"figure": "I"}}],
            "labels": {"localKey": "C:maj"},
        }
        request = subject.event_stream_request("synthetic", normalized)
        self.assertEqual(set(request), {"kind", "id", "endTimestampMs", "frames"})
        self.assertNotIn("events", request)
        self.assertNotIn("labels", request)

    def test_when_in_rome_payload_projects_observations_only(self) -> None:
        with tempfile.TemporaryDirectory(dir=subject.BUILD_ROOT) as directory:
            path = Path(directory) / "synthetic.json"
            path.write_text(
                json.dumps(
                    {
                        "id": "when-in-rome-v1/synthetic",
                        "schema": "whatkey-fixture/1",
                        "events": [
                            {
                                "timestampMs": 100,
                                "durationMs": 250,
                                "midiNotes": [48, 52, 55, 62, 66, 69],
                                "reference": {"figure": "I"},
                                "candidates": [{"quality": "major"}],
                            }
                        ],
                    }
                )
            )
            piece = subject.SourcePiece(
                "when-in-rome",
                "synthetic",
                path,
                "Synthetic fixture",
                subject.sha256_file(path),
            )
            request, source = subject.when_in_rome_request(piece)

        self.assertEqual(set(request), {"kind", "id", "events"})
        self.assertEqual(
            set(request["events"][0]),
            {"id", "timestampMs", "durationMs", "midiNotes"},
        )
        self.assertFalse(source["labelsSuppliedToDart"])
        self.assertFalse(source["storedCandidatesSuppliedToDart"])

    def test_note_names_and_timeline_are_musician_readable(self) -> None:
        self.assertEqual(subject.note_name(60), "C4")
        self.assertEqual(subject.note_name(66), "F#4")
        normalized = {
            "endTimestampMs": 500,
            "events": [
                {"timestampMs": 0, "type": "noteOn", "midiNote": 60},
                {"timestampMs": 250, "type": "noteOff", "midiNote": 60},
                {"timestampMs": 250, "type": "pedal"},
            ],
            "frames": [
                {
                    "afterEventIndex": 0,
                    "timestampMs": 0,
                    "pressedMidiNotes": [60],
                    "sustainedMidiNotes": [],
                    "soundingMidiNotes": [60],
                    "pedalDown": False,
                },
                {
                    "afterEventIndex": 1,
                    "timestampMs": 250,
                    "pressedMidiNotes": [],
                    "sustainedMidiNotes": [60],
                    "soundingMidiNotes": [60],
                    "pedalDown": True,
                },
            ],
        }
        svg = subject.render_timeline_svg(normalized, {"startMs": 200, "endMs": 400})
        self.assertIn("C4", svg)
        self.assertIn('class="pressed"', svg)
        self.assertIn('class="sustained"', svg)
        self.assertIn('class="pedal"', svg)
        self.assertIn('class="attack"', svg)
        self.assertIn('class="release"', svg)
        self.assertIn('class="pedal-change"', svg)

    def test_review_copy_uses_primary_label_instead_of_machine_json(self) -> None:
        item = _review_item()
        rendered = subject.render_review_item(item)
        self.assertIn("Cmaj9 (C major ninth)", rendered)
        self.assertIn("Synthetic source", rendered)
        self.assertIn("lower ends at G3; upper begins at D4; 7 semitones", rendered)
        self.assertNotIn("rootPc", rendered)

    def test_disposition_template_is_bound_and_append_only(self) -> None:
        items = [_review_item()]
        index = subject.review_index(items)
        payload = subject.disposition_template(items)
        judgment = payload["items"][0]["judgments"][0]
        self.assertIsNone(judgment["disposition"])
        self.assertIn("unresolved", payload["allowedDispositions"])
        self.assertIn("in-scope-polychord", payload["allowedDispositions"])
        subject.validate_disposition_payload(
            payload, index["items"], require_complete=False
        )

        judgment.update(
            {
                "disposition": "in-scope-polychord",
                "musicalRationale": "Two complete registral units.",
                "evidenceConsulted": ["review.html", "source score"],
                "reviewer": "Researcher",
                "reviewedAt": "2026-08-11T12:00:00-07:00",
            }
        )
        payload["items"][0]["judgments"].append(
            {
                **judgment,
                "musicalRationale": "Correction retained after score review.",
            }
        )
        subject.validate_disposition_payload(
            payload, index["items"], require_complete=True
        )

        with tempfile.TemporaryDirectory(dir=subject.BUILD_ROOT) as directory:
            index_path = Path(directory) / "review-index.json"
            disposition_path = Path(directory) / "dispositions.json"
            index_path.write_text(json.dumps(index))
            disposition_path.write_text(json.dumps(payload))
            completed = subprocess.run(
                [
                    sys.executable,
                    str(
                        subject.REPO_ROOT
                        / "tool/polychord/validate_development_dispositions.py"
                    ),
                    "--review-index",
                    str(index_path),
                    "--dispositions",
                    str(disposition_path),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
        self.assertIn("Validated 1 complete review items", completed.stdout)

        payload["items"].append(payload["items"][0])
        with self.assertRaisesRegex(ValueError, "duplicate"):
            subject.validate_disposition_payload(
                payload, index["items"], require_complete=True
            )

    def test_aggregate_retains_episode_duration_distribution(self) -> None:
        aggregate = subject._empty_aggregate_profile()
        profile = {
            "frameCounts": {"total": 2},
            "dwellMs": {"sounding": 400},
            "transitionCounts": {"appearance": 2},
            "selectorReasonCounts": {},
            "clearReasonCounts": {"abstention": 2},
            "traceCounts": {},
            "suppressedUnstableSelections": 1,
            "appearanceLatenciesMs": [200, 200],
            "displayedMs": 300,
            "stableEpisodes": [{"durationMs": 100}, {"durationMs": 200}],
            "distinctIdentities": [],
            "distinctAssignments": [],
        }
        subject.add_profile_summary(aggregate, "synthetic", profile)
        result = subject.finalize_profile_summary(aggregate)
        self.assertEqual(
            result["episodeDurationMs"],
            {"n": 2, "min": 100, "median": 100, "p90": 200, "max": 200},
        )


class SourcePlanIsolationTest(unittest.TestCase):
    def test_resolves_and_hashes_only_development_and_sample_sources(self) -> None:
        with tempfile.TemporaryDirectory(dir=subject.BUILD_ROOT) as directory:
            root = Path(directory)
            asap_root = root / "asap"
            pop_root = root / "pop-checkout" / "POP909"
            wir_root = root / "wir"
            asap_development = []
            wir_development = []
            sample = []
            allowed_paths = set()

            for index in range(23):
                title = f"development/piece-{index}"
                path = asap_root / f"{title}.mid"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(f"asap-{index}")
                allowed_paths.add(path)
                asap_development.append({"id": f"asap/{index}", "title": title})
            for index in range(101):
                song_id = f"{index:03d}"
                path = pop_root / song_id / f"{song_id}.mid"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(f"pop-{index}")
                allowed_paths.add(path)
                sample.append(song_id)
            for index in range(59):
                piece_id = f"WIR {index}"
                path = wir_root / f"{piece_id}.json"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(f"wir-{index}")
                allowed_paths.add(path)
                wir_development.append({"id": piece_id})

            split_payloads = {
                subject.ASAP_SPLIT: {
                    "splits": {
                        "development": asap_development,
                        "test": [{"id": "test", "title": "test/not-opened"}],
                    }
                },
                subject.POP909_ROSTER: {"sample": sample, "held": ["held-not-opened"]},
                subject.WIR_SPLIT: {
                    "splits": {
                        "development": wir_development,
                        "test": [{"id": "WIR test not opened"}],
                    }
                },
            }
            hashed_paths = []

            def load_json(path: Path) -> dict:
                return split_payloads[path]

            def hash_file(path: Path) -> str:
                hashed_paths.append(path)
                return "0" * 64

            with (
                patch.object(subject, "WIR_FIXTURE_ROOT", wir_root),
                patch.object(subject, "require_hash") as require_hash,
                patch.object(
                    subject, "require_clean_checkout"
                ) as require_clean_checkout,
                patch.object(subject, "_load_json", side_effect=load_json),
                patch.object(subject, "sha256_file", side_effect=hash_file),
            ):
                plan = subject.load_source_plan(asap_root, pop_root)
                provenance = subject.source_plan_provenance(plan)

        self.assertEqual([len(plan[key]) for key in plan], [23, 101, 59])
        self.assertEqual(require_hash.call_count, 3)
        self.assertEqual(require_clean_checkout.call_count, 2)
        self.assertEqual(set(hashed_paths), allowed_paths)
        self.assertNotIn(asap_root / "test/not-opened.mid", hashed_paths)
        self.assertNotIn(pop_root / "held-not-opened/held-not-opened.mid", hashed_paths)
        self.assertNotIn(wir_root / "WIR test not opened.json", hashed_paths)
        self.assertEqual(provenance["asap"]["sourceCommit"], subject.ASAP_COMMIT)
        self.assertEqual(provenance["pop909"]["pieceCount"], 101)

    def test_detects_source_mutation_after_plan_resolution(self) -> None:
        with tempfile.TemporaryDirectory(dir=subject.BUILD_ROOT) as directory:
            path = Path(directory) / "source.mid"
            path.write_text("before")
            piece = subject.SourcePiece(
                "asap", "one", path, "One", subject.sha256_file(path)
            )
            path.write_text("after")
            with self.assertRaisesRegex(ValueError, "changed after plan"):
                subject._verify_piece_source(piece)


class DartBatchIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.batch = subject.DartBatch()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.batch.close()

    def test_timer_result_matches_frozen_python_control(self) -> None:
        notes = [48, 52, 55, 62, 66, 69]
        request = _stream_request(notes, end_timestamp_ms=300)
        result = self.batch.analyze(request)
        subject.validate_event_result(request, result)
        profile = result["profiles"][subject.FULL_SELECTOR_ID]
        self.assertEqual(profile["appearanceLatenciesMs"], [200])
        self.assertEqual(profile["displayedMs"], 100)
        self.assertEqual(len(profile["stableEpisodes"]), 1)

        selected = result["frames"][0]["profiles"][subject.FULL_SELECTOR_ID][
            "decision"
        ]["selected"]
        python_candidate = _python_candidate(selected)
        gate = decision_contract.StableDisplayGate()
        first = gate.step(
            timestamp_ms=0,
            raw_selected=python_candidate,
            primary_displayable=True,
            sounding_midi_notes=notes,
        )
        appeared = gate.step(
            timestamp_ms=200,
            raw_selected=python_candidate,
            primary_displayable=True,
            sounding_midi_notes=notes,
        )
        self.assertEqual(first["transition"], "pending")
        self.assertEqual(appeared["transition"], "appearance")
        self.assertEqual(profile["stableEpisodes"][0]["selected"]["symbol"], "D|C")
        self.assertIsNotNone(profile["stableEpisodes"][0]["selectionEvidence"])
        self.assertEqual(result["frames"][0]["primaryContextAudit"]["contextCount"], 48)
        self.assertTrue(
            result["frames"][0]["primaryContextAudit"]["availabilityInvariant"]
        )
        self.assertEqual(set(result["profiles"]), set(subject.SELECTOR_IDS))
        self.assertIn("symbol", result["frames"][0]["primary"])

    def test_deadline_tied_with_source_event_is_processed_first(self) -> None:
        notes = [48, 52, 55, 62, 66, 69]
        request = _stream_request(notes, end_timestamp_ms=250)
        request["frames"].append(
            {
                "afterEventIndex": 1,
                "timestampMs": 200,
                "pressedMidiNotes": [48, 52, 55, 62, 66],
                "sustainedMidiNotes": [],
                "soundingMidiNotes": [48, 52, 55, 62, 66],
                "pedalDown": False,
            }
        )
        result = self.batch.analyze(request)
        subject.validate_event_result(request, result)
        episodes = result["profiles"][subject.FULL_SELECTOR_ID]["stableEpisodes"]
        self.assertEqual(len(episodes), 1)
        self.assertEqual(episodes[0]["startMs"], 200)
        self.assertEqual(episodes[0]["endMs"], 200)
        self.assertEqual(episodes[0]["durationMs"], 0)

    def test_committed_events_remain_proposals_without_display_state(self) -> None:
        request = {
            "kind": "committedEvents",
            "id": "synthetic-committed",
            "events": [
                {
                    "id": "event-0",
                    "timestampMs": 100,
                    "durationMs": 500,
                    "midiNotes": [48, 52, 55, 62, 66, 69],
                }
            ],
        }
        result = self.batch.analyze(request)
        subject.validate_committed_result(request, result)
        self.assertNotIn("profiles", result)
        self.assertEqual(
            set(result["events"][0]["profiles"]), set(subject.SELECTOR_IDS)
        )
        self.assertNotIn("stableEpisodes", result["events"][0])


def _stream_request(notes: list[int], end_timestamp_ms: int) -> dict:
    return {
        "kind": "eventStream",
        "id": f"synthetic-{end_timestamp_ms}",
        "endTimestampMs": end_timestamp_ms,
        "frames": [
            {
                "afterEventIndex": 0,
                "timestampMs": 0,
                "pressedMidiNotes": notes,
                "sustainedMidiNotes": [],
                "soundingMidiNotes": notes,
                "pedalDown": False,
            }
        ],
    }


def _python_candidate(dart_candidate: dict) -> dict:
    return {
        "identity": {
            "upper": {
                "rootPc": dart_candidate["upper"]["rootPc"],
                "quality": dart_candidate["upper"]["quality"],
            },
            "lower": {
                "rootPc": dart_candidate["lower"]["rootPc"],
                "quality": dart_candidate["lower"]["quality"],
            },
        },
        "upperMidiNotes": dart_candidate["upper"]["midiNotes"],
        "lowerMidiNotes": dart_candidate["lower"]["midiNotes"],
    }


def _review_item() -> dict:
    selected = {
        "symbol": "D|C",
        "lowerTopMidi": 55,
        "upperBottomMidi": 62,
        "gapSemitones": 7,
        "upper": {
            "rootPc": 2,
            "quality": "major",
            "midiNotes": [62, 66, 69],
        },
        "lower": {
            "rootPc": 0,
            "quality": "major",
            "midiNotes": [48, 52, 55],
        },
    }
    episode = {
        "episodeIndex": 0,
        "startMs": 200,
        "endMs": 400,
        "durationMs": 200,
    }
    return {
        "itemId": "asap:one:display-0",
        "kind": "stableDisplay",
        "corpus": "asap",
        "pieceId": "one",
        "sourceTitle": "Synthetic source",
        "sourcePath": "/synthetic/source.mid",
        "selected": selected,
        "soundingMidiNotes": [48, 52, 55, 62, 66, 69],
        "primary": {
            "symbol": "Cmaj9",
            "longLabel": "C major ninth",
            "identity": {"rootPc": 0},
        },
        "surroundingPrimaryChanges": [
            {
                "timestampMs": 0,
                "primary": {
                    "symbol": "Cmaj9",
                    "longLabel": "C major ninth",
                    "identity": {"rootPc": 0},
                },
            }
        ],
        "episode": episode,
        "normalized": {
            "endTimestampMs": 500,
            "events": [],
            "frames": [
                {
                    "afterEventIndex": 0,
                    "timestampMs": 0,
                    "pressedMidiNotes": [48, 52, 55, 62, 66, 69],
                    "sustainedMidiNotes": [],
                    "soundingMidiNotes": [48, 52, 55, 62, 66, 69],
                    "pedalDown": False,
                }
            ],
        },
    }


if __name__ == "__main__":
    unittest.main()
