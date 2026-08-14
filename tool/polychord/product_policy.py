"""Implement the frozen onset-licensed automatic polychord product policy.

This module is the independent Python reference for
``polychord-onset-register-policy/1`` and ``polychord-output/3``. It composes
the already-frozen structural, onset-evidence, and instance-binding substrate;
it does not read product-suite expectations or primary chord identities.
"""

from __future__ import annotations

from collections import Counter
from collections.abc import Sequence

import onset_evidence
import register_candidates
import register_selector

OUTPUT_SCHEMA = "polychord-output/3"
INPUT_CONDITION = "automaticTimestampedMidi"
TRACKER_ID = "polychord-onset-tracker/1"
CANDIDATE_GENERATOR_ID = register_candidates.OUTPUT_SCHEMA
CUE_ID = "coherent-separated-onsets-50-80ms/product-1"
SELECTOR_ID = "polychord-onset-register-policy/1"
DISPLAY_ID = "polychord-continuous-authorization-200ms/1"
DECISION_SCHEMA = "polychord-onset-register-decision/1"
EVIDENCE_SCHEMA_ID = onset_evidence.OUTPUT_SCHEMA

WITHIN_LAYER_COHORT_SPAN_MAXIMUM_MS = 50
BETWEEN_LAYER_SEPARATION_MINIMUM_MS = 80
DISPLAY_STABILITY_MS = 200

NO_STRUCTURAL_CANDIDATE = "no-structural-candidate"
AMBIGUOUS_EXACT_ASSIGNMENT = "ambiguous-exact-assignment"
INTEGRATED_TERTIAN_READING = "integrated-tertian-reading"
LAYER_SEPARATION_NOT_SUPPORTED = "layer-separation-not-supported"
MISSING_LAYER_SEPARATION_HISTORY = "missing-layer-separation-history"

VERSION_IDS = {
    "output": OUTPUT_SCHEMA,
    "tracker": TRACKER_ID,
    "candidateGenerator": CANDIDATE_GENERATOR_ID,
    "cue": CUE_ID,
    "selector": SELECTOR_ID,
    "display": DISPLAY_ID,
}


def product_onset_interpretation(evidence: dict) -> dict:
    """Apply the frozen inclusive 50/80-ms product cue to raw evidence."""

    if not evidence["allCandidateOnsetsKnown"]:
        return {
            "availability": "incomplete",
            "lowerWithinCohortSpanMaximum": None,
            "upperWithinCohortSpanMaximum": None,
            "layerOnsetOrder": None,
            "betweenLayerOnsetIntervalGapMs": None,
            "onsetCohortSupport": "neutral",
            "reasonCodes": ["onset-history-incomplete"],
        }

    lower = evidence["lower"]
    upper = evidence["upper"]
    lower_coherent = lower["knownOnsetSpanMs"] <= WITHIN_LAYER_COHORT_SPAN_MAXIMUM_MS
    upper_coherent = upper["knownOnsetSpanMs"] <= WITHIN_LAYER_COHORT_SPAN_MAXIMUM_MS
    lower_earliest = lower["earliestKnownOnsetMs"]
    lower_latest = lower["latestKnownOnsetMs"]
    upper_earliest = upper["earliestKnownOnsetMs"]
    upper_latest = upper["latestKnownOnsetMs"]
    if lower_latest < upper_earliest:
        order = "lower-then-upper"
        gap_ms = upper_earliest - lower_latest
    elif upper_latest < lower_earliest:
        order = "upper-then-lower"
        gap_ms = lower_earliest - upper_latest
    else:
        order = "overlapping"
        gap_ms = 0

    reasons = []
    if not lower_coherent:
        reasons.append("lower-span-exceeds-maximum")
    if not upper_coherent:
        reasons.append("upper-span-exceeds-maximum")
    if gap_ms < BETWEEN_LAYER_SEPARATION_MINIMUM_MS:
        reasons.append("between-layer-separation-below-minimum")
    positive = not reasons
    return {
        "availability": "complete",
        "lowerWithinCohortSpanMaximum": lower_coherent,
        "upperWithinCohortSpanMaximum": upper_coherent,
        "layerOnsetOrder": order,
        "betweenLayerOnsetIntervalGapMs": gap_ms,
        "onsetCohortSupport": "positive" if positive else "neutral",
        "reasonCodes": (["separate-coherent-onset-cohorts"] if positive else reasons),
    }


def frame_document(
    *, tracker_epoch: int, frame: dict, onset_frame: onset_evidence.OnsetFrame
) -> dict:
    """Serialize one shared replay/onset frame in the Dart product shape."""

    if frame["afterEventIndex"] != onset_frame.after_event_index:
        raise ValueError("frame and onset frame event indices differ")
    if frame["timestampMs"] != onset_frame.timestamp_ms:
        raise ValueError("frame and onset frame timestamps differ")
    return {
        "trackerEpoch": tracker_epoch,
        "afterEventIndex": frame["afterEventIndex"],
        "timestampMs": frame["timestampMs"],
        "pressedMidiNotes": frame["pressedMidiNotes"],
        "sustainedMidiNotes": frame["sustainedMidiNotes"],
        "soundingMidiNotes": frame["soundingMidiNotes"],
        "pedalDown": frame["pedalDown"],
        "onsetNotes": [note.as_dict() for note in onset_frame.notes],
    }


def _candidate_binding(
    *,
    tracker_epoch: int,
    candidate: register_candidates.RegisterCandidate,
    onset_frame: onset_evidence.OnsetFrame,
) -> dict:
    note_map = onset_frame.note_map()
    assigned_notes = sorted((*candidate.lower.midi_notes, *candidate.upper.midi_notes))
    instances = [
        {
            "midiNote": midi_note,
            "onsetEventIndex": (
                None
                if note_map[midi_note].origin is None
                else note_map[midi_note].origin.event_index
            ),
        }
        for midi_note in assigned_notes
    ]
    return {
        "trackerEpoch": tracker_epoch,
        "candidate": candidate.as_dict(),
        "targetInstances": instances,
        "availability": (
            "complete"
            if all(item["onsetEventIndex"] is not None for item in instances)
            else "incomplete"
        ),
    }


def product_cue_record(
    *,
    tracker_epoch: int,
    observation: dict,
    candidate: register_candidates.RegisterCandidate,
    onset_frame: onset_evidence.OnsetFrame,
) -> dict:
    """Build one exact candidate-bound record for the product onset cue."""

    item = onset_evidence.candidate_onset_evidence(candidate, onset_frame)
    evidence = item["onsetEvidence"]
    interpretation = product_onset_interpretation(evidence)
    binding = _candidate_binding(
        tracker_epoch=tracker_epoch,
        candidate=candidate,
        onset_frame=onset_frame,
    )
    complete = interpretation["availability"] == "complete"
    if complete != (binding["availability"] == "complete"):
        raise ValueError("cue interpretation and binding availability differ")
    return {
        "cueId": CUE_ID,
        "evidenceSchemaId": EVIDENCE_SCHEMA_ID,
        "targetObservation": observation,
        "targetBinding": binding,
        "availability": "complete" if complete else "incomplete",
        "support": interpretation["onsetCohortSupport"] if complete else None,
        "reasonCodes": interpretation["reasonCodes"],
        "diagnostic": {
            "candidate": candidate.as_dict(),
            "onsetEvidence": evidence,
            "onsetInterpretation": interpretation,
        },
    }


def _identity_key(candidate: register_candidates.RegisterCandidate) -> tuple:
    return (
        candidate.upper.root_pitch_class,
        candidate.upper.quality,
        candidate.lower.root_pitch_class,
        candidate.lower.quality,
    )


def _terminal_predicates(
    stages: dict[str, list[dict]], reason: str | None
) -> list[dict]:
    reason_by_stage = {
        "structural": NO_STRUCTURAL_CANDIDATE,
        "assignment": AMBIGUOUS_EXACT_ASSIGNMENT,
        "integrated": INTEGRATED_TERTIAN_READING,
        "positiveSupport": (
            reason
            if reason
            in {LAYER_SEPARATION_NOT_SUPPORTED, MISSING_LAYER_SEPARATION_HISTORY}
            else None
        ),
    }
    return [
        {
            "stage": stage,
            "survivorCount": len(stages[stage]),
            "terminal": reason is not None and reason_by_stage[stage] == reason,
        }
        for stage in ("structural", "assignment", "integrated", "positiveSupport")
    ]


def decision_document(
    *, observation: dict, onset_frame: onset_evidence.OnsetFrame
) -> dict:
    """Return the complete raw onset-licensed decision for one frame."""

    midi_notes = register_candidates.validate_midi_notes(
        observation["soundingMidiNotes"]
    )
    candidates = register_candidates.generate_register_candidates(midi_notes)
    records = tuple(
        product_cue_record(
            tracker_epoch=observation["trackerEpoch"],
            observation=observation,
            candidate=candidate,
            onset_frame=onset_frame,
        )
        for candidate in candidates
    )
    identity_counts = Counter(_identity_key(candidate) for candidate in candidates)
    assignment_survivors = tuple(
        candidate
        for candidate in candidates
        if identity_counts[_identity_key(candidate)] == 1
    )
    integrated_by_candidate = {
        candidate: register_selector.integrated_tertian_tests(midi_notes, candidate)
        for candidate in candidates
    }
    integrated_survivors = tuple(
        candidate
        for candidate in assignment_survivors
        if not any(integrated_by_candidate[candidate].values())
    )
    record_by_candidate = dict(zip(candidates, records, strict=True))
    positive_survivors = tuple(
        candidate
        for candidate in integrated_survivors
        if record_by_candidate[candidate]["availability"] == "complete"
        and record_by_candidate[candidate]["support"] == "positive"
    )
    if len(positive_survivors) > 1:
        raise AssertionError("positive-survivor uniqueness was violated")

    if not candidates:
        reason = NO_STRUCTURAL_CANDIDATE
    elif not assignment_survivors:
        reason = AMBIGUOUS_EXACT_ASSIGNMENT
    elif not integrated_survivors:
        reason = INTEGRATED_TERTIAN_READING
    elif not positive_survivors:
        reason = (
            LAYER_SEPARATION_NOT_SUPPORTED
            if any(
                record_by_candidate[candidate]["availability"] == "complete"
                and record_by_candidate[candidate]["support"] == "neutral"
                for candidate in integrated_survivors
            )
            else MISSING_LAYER_SEPARATION_HISTORY
        )
    else:
        reason = None

    selected = positive_survivors[0] if positive_survivors else None
    traces = []
    for candidate in candidates:
        record = record_by_candidate[candidate]
        aggregate = (
            "unavailable" if record["availability"] != "complete" else record["support"]
        )
        if candidate not in assignment_survivors:
            removed_at = "assignment"
        elif candidate not in integrated_survivors:
            removed_at = "integrated"
        elif candidate not in positive_survivors:
            removed_at = "support"
        else:
            removed_at = None
        traces.append(
            {
                "candidate": candidate.as_dict(),
                "identityAssignmentCount": identity_counts[_identity_key(candidate)],
                "integratedTertian": integrated_by_candidate[candidate],
                "aggregateSupport": aggregate,
                "removedAt": removed_at,
                "selected": candidate == selected,
            }
        )

    stages = {
        "structural": [candidate.as_dict() for candidate in candidates],
        "assignment": [candidate.as_dict() for candidate in assignment_survivors],
        "integrated": [candidate.as_dict() for candidate in integrated_survivors],
        "positiveSupport": [candidate.as_dict() for candidate in positive_survivors],
    }
    selected_record = record_by_candidate.get(selected)
    return {
        "schema": DECISION_SCHEMA,
        "selectorId": SELECTOR_ID,
        "targetObservation": observation,
        "candidates": [candidate.as_dict() for candidate in candidates],
        "candidateRecords": list(records),
        "stageSurvivors": stages,
        "candidateTraces": traces,
        "selected": None if selected is None else selected.as_dict(),
        "selectedBinding": (
            None if selected_record is None else selected_record["targetBinding"]
        ),
        "reasonCode": reason,
        "terminalPredicates": _terminal_predicates(stages, reason),
    }


def authorization_document(*, primary_displayable: bool, decision: dict) -> dict:
    """Reduce primary availability and a raw decision to one exact key."""

    if not primary_displayable:
        return {"key": None, "reasonCode": "primary-not-displayable"}
    binding = decision["selectedBinding"]
    if binding is None:
        return {"key": None, "reasonCode": decision["reasonCode"]}
    if binding["availability"] != "complete":
        raise AssertionError("a selected candidate must have a complete binding")
    return {
        "key": {
            "trackerEpoch": binding["trackerEpoch"],
            "candidate": binding["candidate"],
            "targetInstances": binding["targetInstances"],
        },
        "reasonCode": None,
    }


class ContinuousAuthorizationDisplay:
    """Pure state reducer for continuous exact authorization."""

    def __init__(self, minimum_duration_ms: int = DISPLAY_STABILITY_MS) -> None:
        if minimum_duration_ms < 0:
            raise ValueError("minimum_duration_ms must be nonnegative")
        self.minimum_duration_ms = minimum_duration_ms
        self.state = "absent"
        self.key: dict | None = None
        self.deadline_ms: int | None = None

    @staticmethod
    def _same_key(left: dict | None, right: dict | None) -> bool:
        return left == right

    def _result(self, transition: str, reason: str | None) -> dict:
        return {
            "profileId": DISPLAY_ID,
            "state": self.state,
            "transition": transition,
            "key": self.key,
            "deadlineMs": self.deadline_ms,
            "reasonCode": reason,
        }

    def _clear(self, reason: str) -> dict:
        active = self.state != "absent"
        self.state = "absent"
        self.key = None
        self.deadline_ms = None
        return self._result("clear" if active else "none", reason if active else None)

    def reset(self) -> dict:
        active = self.state != "absent"
        self.state = "absent"
        self.key = None
        self.deadline_ms = None
        return self._result("clear" if active else "none", "tracker-reset")

    def step(
        self,
        *,
        timestamp_ms: int,
        frame: dict,
        candidate_records: Sequence[dict],
        authorization: dict,
    ) -> dict:
        new_key = authorization["key"]
        if new_key is not None:
            if self.state == "absent":
                self.state = "pending"
                self.key = new_key
                self.deadline_ms = timestamp_ms + self.minimum_duration_ms
                return self._result("pending", "awaiting-display-stability")
            if not self._same_key(self.key, new_key):
                self.state = "pending"
                self.key = new_key
                self.deadline_ms = timestamp_ms + self.minimum_duration_ms
                return self._result("pending", "authorization-key-changed")
            if self.state == "visible":
                return self._result("stable", None)
            if timestamp_ms >= self.deadline_ms:
                self.state = "visible"
                self.deadline_ms = None
                return self._result("appearance", None)
            return self._result("none", "awaiting-display-stability")

        if self.state == "absent":
            return self._result("none", None)
        if not frame["soundingMidiNotes"]:
            return self._clear("silence")
        if authorization["reasonCode"] == "primary-not-displayable":
            return self._clear("primary-not-displayable")
        previous_key = self.key
        assert previous_key is not None
        for record in candidate_records:
            binding = record["targetBinding"]
            if (
                binding["trackerEpoch"] == previous_key["trackerEpoch"]
                and binding["candidate"] == previous_key["candidate"]
                and binding["targetInstances"] != previous_key["targetInstances"]
            ):
                return self._clear("invalidated-support-binding")
        return self._clear("raw-selector-abstention")


class ProductPolicySession:
    """Compose raw decisions, authorization, and display state for one stream."""

    def __init__(self, *, initial_primary_displayable: bool) -> None:
        self.primary_displayable = initial_primary_displayable
        self.display = ContinuousAuthorizationDisplay()
        self.observation: dict | None = None
        self.decision: dict | None = None
        self.authorization: dict | None = None

    def _document(self, *, timestamp_ms: int, display: dict) -> dict:
        decision = self.decision
        return {
            "schema": OUTPUT_SCHEMA,
            "inputCondition": INPUT_CONDITION,
            "observationTimestampMs": timestamp_ms,
            "frame": self.observation,
            "candidates": [] if decision is None else decision["candidates"],
            "candidateRecords": (
                [] if decision is None else decision["candidateRecords"]
            ),
            "rawDecision": decision,
            "authorization": self.authorization,
            "display": display,
            "versionIds": VERSION_IDS,
        }

    def observe_frame(
        self,
        *,
        tracker_epoch: int,
        frame: dict,
        onset_frame: onset_evidence.OnsetFrame,
    ) -> dict:
        self.observation = frame_document(
            tracker_epoch=tracker_epoch,
            frame=frame,
            onset_frame=onset_frame,
        )
        self.decision = decision_document(
            observation=self.observation,
            onset_frame=onset_frame,
        )
        self.authorization = authorization_document(
            primary_displayable=self.primary_displayable,
            decision=self.decision,
        )
        display = self.display.step(
            timestamp_ms=frame["timestampMs"],
            frame=self.observation,
            candidate_records=self.decision["candidateRecords"],
            authorization=self.authorization,
        )
        return self._document(timestamp_ms=frame["timestampMs"], display=display)

    def observe_timer(self, timestamp_ms: int) -> dict:
        if (
            self.observation is None
            or self.decision is None
            or self.authorization is None
        ):
            raise ValueError("a timer observation requires a prior musical frame")
        display = self.display.step(
            timestamp_ms=timestamp_ms,
            frame=self.observation,
            candidate_records=self.decision["candidateRecords"],
            authorization=self.authorization,
        )
        return self._document(timestamp_ms=timestamp_ms, display=display)

    def set_primary_displayable(self, *, timestamp_ms: int, displayable: bool) -> dict:
        if self.observation is None or self.decision is None:
            raise ValueError("primary availability requires a prior musical frame")
        self.primary_displayable = displayable
        self.authorization = authorization_document(
            primary_displayable=displayable,
            decision=self.decision,
        )
        display = self.display.step(
            timestamp_ms=timestamp_ms,
            frame=self.observation,
            candidate_records=self.decision["candidateRecords"],
            authorization=self.authorization,
        )
        return self._document(timestamp_ms=timestamp_ms, display=display)

    def reset(self, timestamp_ms: int) -> dict:
        self.observation = None
        self.decision = None
        self.authorization = None
        return self._document(timestamp_ms=timestamp_ms, display=self.display.reset())
