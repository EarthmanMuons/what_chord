import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  InstrumentValidationError,
  addLayer,
  assignMidiNote,
  buildCompletedPacket,
  createInstrumentState,
} from "../../research/polychord/review-instrument/model.mjs";

const ROOT = dirname(dirname(dirname(fileURLToPath(import.meta.url))));
const PACKET = join(ROOT, "research/polychord/pilot-review-template-v0.json");
const RULER = join(ROOT, "research/polychord/pilot-ruler-v0.json");
const GUIDE = join(ROOT, "research/polychord/pilot-annotation.md");
const APP = join(ROOT, "research/polychord/review-instrument/app.mjs");
const HTML = join(ROOT, "research/polychord/review-instrument/index.html");

function sha256(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function loadTemplate() {
  return JSON.parse(readFileSync(PACKET, "utf8"));
}

function completeMechanicalFixture(template) {
  const state = createInstrumentState(template);
  state.annotatorId = "reviewer-test-01";
  state.completedOn = "2026-08-02";
  state.responses.forEach((response, caseIndex) => {
    response.observationKind =
      template.cases[caseIndex].evidence.kind === "score-source"
        ? "event-window"
        : "snapshot";
    response.constructionTag = "abstain";
    response.confidence = "low";
    response.notes = "Mechanical validator fixture, not a research annotation.";
    for (const judgment of Object.values(response.inputEligibility)) {
      judgment.status = "unknown";
      judgment.reason = "Mechanical validator fixture.";
    }
  });
  return state;
}

test("instrument pins the exact packet and guide and exposes accessible landmarks", () => {
  const template = loadTemplate();
  const app = readFileSync(APP, "utf8");
  const html = readFileSync(HTML, "utf8");

  assert.match(app, new RegExp(sha256(PACKET)));
  assert.equal(template.annotationGuide.sha256, sha256(GUIDE));
  assert.match(html, /<html lang="en">/);
  assert.match(html, /class="skip-link" href="#main-content"/);
  assert.match(html, /role="status"\s+aria-live="polite"/);
  assert.match(html, /Content-Security-Policy/);
  assert.doesNotMatch(html, /<script(?![^>]*src=)[^>]*>/);
});

test("completed export preserves frozen evidence and passes the Python validator", () => {
  const template = loadTemplate();
  const originalTemplate = JSON.stringify(template);
  const state = completeMechanicalFixture(template);
  const originalEvidence = template.cases.map(
    (reviewCase) => reviewCase.evidence,
  );

  const firstResponse = state.responses[0];
  const firstEvidence = template.cases[0].evidence;
  firstResponse.constructionTag = "positive";
  addLayer(firstResponse, firstEvidence);
  addLayer(firstResponse, firstEvidence);
  for (const midiNote of firstEvidence.midiNotes.slice(0, 3)) {
    assignMidiNote(firstResponse, firstEvidence, midiNote, "0");
  }
  for (const midiNote of firstEvidence.midiNotes.slice(3)) {
    assignMidiNote(firstResponse, firstEvidence, midiNote, "1");
  }
  firstResponse.layers[0].identity = "mechanical lower layer";
  firstResponse.layers[1].identity = "mechanical upper layer";

  const completed = buildCompletedPacket(template, state);

  assert.equal(JSON.stringify(template), originalTemplate);
  assert.deepEqual(
    completed.cases.map((reviewCase) => reviewCase.evidence),
    originalEvidence,
  );
  assert.deepEqual(completed.cases[0].response.sharedPitchClasses, [7]);
  assert.equal(completed.status, "complete");

  const temporaryDirectory = mkdtempSync(join(tmpdir(), "polychord-review-"));
  const completedPath = join(temporaryDirectory, "completed.json");
  try {
    writeFileSync(completedPath, `${JSON.stringify(completed, null, 2)}\n`);
    execFileSync(
      "python3",
      [
        "tool/polychord/pilot_ruler.py",
        RULER,
        "--validate-review",
        completedPath,
      ],
      { cwd: ROOT, stdio: "pipe" },
    );
  } finally {
    rmSync(temporaryDirectory, { recursive: true, force: true });
  }
});

test("positive response rejects empty synthetic layers", () => {
  const template = loadTemplate();
  const state = completeMechanicalFixture(template);
  const response = state.responses[0];
  const evidence = template.cases[0].evidence;
  response.constructionTag = "positive";
  addLayer(response, evidence);
  addLayer(response, evidence);
  response.layers[0].identity = "empty lower";
  response.layers[1].identity = "empty upper";

  assert.throws(
    () => buildCompletedPacket(template, state),
    (error) =>
      error instanceof InstrumentValidationError &&
      error.errors.some((issue) =>
        issue.message.includes("assigned MIDI note"),
      ),
  );
});

test("export rejects incomplete metadata and eligibility reasons", () => {
  const template = loadTemplate();
  const state = completeMechanicalFixture(template);
  state.annotatorId = "person@example.com";
  state.responses[2].inputEligibility.pitchRegisterSnapshot.reason = "";

  assert.throws(
    () => buildCompletedPacket(template, state),
    (error) =>
      error instanceof InstrumentValidationError &&
      error.errors.some((issue) => issue.fieldId === "annotator-id") &&
      error.errors.some(
        (issue) => issue.fieldId === "case-2-pitchRegisterSnapshot-reason",
      ),
  );
});
