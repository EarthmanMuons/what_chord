import {
  CONFIDENCE_LEVELS,
  CONSTRUCTION_TAGS,
  ELIGIBILITY_STATUSES,
  INPUT_CONDITIONS,
  INSTRUMENT_VERSION,
  OBSERVATION_KINDS,
  InstrumentValidationError,
  addLayer,
  assignMidiNote,
  buildCompletedPacket,
  caseIsComplete,
  createInstrumentState,
  midiDestination,
  refreshDerivedFields,
  removeLayer,
} from "./model.mjs";
import {
  ORIENTATION_EXAMPLES,
  PITCH_CLASS_LABELS,
  READINESS_QUESTIONS,
  assertPresentationManifest,
  formatNoteList,
  formatOnsetTime,
  midiNoteLabel,
  pitchClassLabel,
  readinessIsComplete,
  scoreExcerptForEvidence,
} from "./presentation.mjs";

const EXPECTED_PACKET_SHA256 =
  "1817a75b0b2a59e6a736ae7c84f10d3010564e3ec495959d16ff89f00af3cbe5";
const EXPECTED_PRESENTATION_SHA256 =
  "a77bcab355ddeafde6804353235834c2e820164256c7a5fce0c7cfcd44cdeb6b";
const PACKET_PATH = "../pilot-review-template-v0.json";
const GUIDE_PATH = "../pilot-annotation.md";
const PRESENTATION_PATH = "assets/manifest.json";
const STORAGE_KEY = `${INSTRUMENT_VERSION}:${EXPECTED_PACKET_SHA256}`;

const LABELS = {
  snapshot: "One simultaneous sonority",
  "event-window": "A short passage unfolding over time",
  positive: "Polychord reading expected",
  boundary: "Possible decomposition, but a single-chord reading is preferable",
  "negative-guard": "A polychord reading would be misleading",
  abstain: "Cannot determine from the instructions or evidence",
  low: "Low",
  medium: "Medium",
  high: "High",
  eligible: "Enough evidence",
  ambiguous: "More than one defensible reading",
  ineligible: "Not enough evidence",
  "research-candidate": "Promising, but needs a timed performance",
  unknown: "Not known from this case",
  adjacentRegisterSnapshot: "One split between neighboring notes",
  pitchRegisterSnapshot: "Any assignment using pitch and register",
  timestampedEventStream: "Timing and motion available",
};

const INPUT_HELP = {
  adjacentRegisterSnapshot:
    "Sort the simultaneously sounding notes from low to high and place one boundary between adjacent notes.",
  pitchRegisterSnapshot:
    "Use the simultaneous octave-specific notes, allowing non-contiguous layer assignments.",
  timestampedEventStream:
    "Use attack time, release, sustain-pedal state, or coherent layer motion in addition to pitch and register.",
};

const loadingPanel = document.querySelector("#loading-panel");
const loadErrorPanel = document.querySelector("#load-error");
const loadErrorMessage = document.querySelector("#load-error-message");
const instrument = document.querySelector("#instrument");
const orientationPanel = document.querySelector("#orientation-panel");
const reviewWorkspace = document.querySelector("#review-workspace");
const orientationExamples = document.querySelector("#orientation-examples");
const readinessForm = document.querySelector("#readiness-form");
const readinessQuestions = document.querySelector("#readiness-questions");
const readinessMessage = document.querySelector("#readiness-message");
const reviewForm = document.querySelector("#review-form");
const annotatorIdInput = document.querySelector("#annotator-id");
const completedOnInput = document.querySelector("#completed-on");
const generateIdButton = document.querySelector("#generate-id");
const clearDraftButton = document.querySelector("#clear-draft");
const navigationList = document.querySelector("#case-navigation-list");
const progressSummary = document.querySelector("#progress-summary");
const casePanel = document.querySelector("#case-panel");
const errorSummary = document.querySelector("#error-summary");
const errorList = document.querySelector("#error-list");
const statusMessage = document.querySelector("#status-message");

let template;
let presentationManifest;
let state;
let visibleErrors = [];
let saveTimer;
let storageAvailable = true;
const scoreAssetUrls = new Map();

function element(tagName, options = {}) {
  const node = document.createElement(tagName);
  if (options.id) node.id = options.id;
  if (options.className) node.className = options.className;
  if (options.text !== undefined) node.textContent = options.text;
  return node;
}

function append(parent, ...children) {
  for (const child of children) {
    if (child) parent.append(child);
  }
  return parent;
}

async function sha256Bytes(bytes) {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function sha256(text) {
  return sha256Bytes(new TextEncoder().encode(text));
}

async function loadPinnedText(path, expectedDigest, description) {
  const response = await fetch(path, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`${description} returned HTTP ${response.status}.`);
  }
  const text = await response.text();
  const actualDigest = await sha256(text);
  if (actualDigest !== expectedDigest) {
    console.error(
      `${description} digest mismatch: expected ${expectedDigest}, received ${actualDigest}.`,
    );
    throw new Error(`${description} could not be verified.`);
  }
  return text;
}

async function loadPinnedImage(path, expectedDigest, description) {
  const response = await fetch(path, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`${description} returned HTTP ${response.status}.`);
  }
  const bytes = await response.arrayBuffer();
  const actualDigest = await sha256Bytes(bytes);
  if (actualDigest !== expectedDigest) {
    console.error(
      `${description} digest mismatch: expected ${expectedDigest}, received ${actualDigest}.`,
    );
    throw new Error(`${description} could not be verified.`);
  }
  return URL.createObjectURL(new Blob([bytes], { type: "image/png" }));
}

function recoverDraft(freshState) {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (!saved) return freshState;
    const candidate = JSON.parse(saved);
    if (
      candidate.instrumentVersion !== INSTRUMENT_VERSION ||
      typeof candidate.orientationComplete !== "boolean" ||
      !Array.isArray(candidate.responses) ||
      candidate.responses.length !== freshState.responses.length ||
      !candidate.responses.every(
        (response) =>
          response &&
          Array.isArray(response.layers) &&
          Array.isArray(response.unassignedMidiNotes) &&
          Array.isArray(response.singleChordAlternatives) &&
          response.inputEligibility,
      )
    ) {
      throw new Error("incompatible draft");
    }
    candidate.currentCaseIndex = Math.min(
      Math.max(Number(candidate.currentCaseIndex) || 0, 0),
      freshState.responses.length - 1,
    );
    candidate.responses.forEach((response, caseIndex) => {
      refreshDerivedFields(response, template.cases[caseIndex].evidence);
    });
    setStatus("Recovered your saved answers.");
    return candidate;
  } catch {
    try {
      localStorage.removeItem(STORAGE_KEY);
      setStatus(
        "Started a new review because the previous saved answers could not be used.",
        "error",
      );
    } catch {
      storageAvailable = false;
      setStatus(
        "Your answers cannot be saved in this browser. Keep this page open until you finish.",
        "error",
      );
    }
    return freshState;
  }
}

function persistDraft(announce = true) {
  if (!storageAvailable) return;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    if (announce) setStatus("Answers saved in this browser.");
  } catch {
    storageAvailable = false;
    setStatus(
      "Your answers cannot be saved in this browser. Keep this page open until you finish.",
      "error",
    );
  }
}

function saveDraft() {
  window.clearTimeout(saveTimer);
  saveTimer = window.setTimeout(() => {
    persistDraft();
  }, 500);
}

function setStatus(message, kind = "") {
  statusMessage.textContent = message;
  statusMessage.className = `status-message${kind ? ` ${kind}` : ""}`;
}

function responseChanged() {
  saveDraft();
  renderNavigation();
}

function radioGroup({ id, legend, values, selected, help, onChange }) {
  const fieldset = element("fieldset", { id, className: "choice-group" });
  fieldset.append(element("legend", { text: legend }));
  if (help) {
    const helpId = `${id}-help`;
    const helpText = element("p", {
      id: helpId,
      className: "help",
      text: help,
    });
    fieldset.setAttribute("aria-describedby", helpId);
    fieldset.append(helpText);
  }
  const choices = element("div", { className: "choice-list" });
  values.forEach((value) => {
    const optionId = `${id}-${value}`;
    const input = element("input", { id: optionId });
    input.type = "radio";
    input.name = id;
    input.value = value;
    input.checked = selected === value;
    input.addEventListener("change", () => {
      if (input.checked) onChange(value);
    });
    const label = element("label", { className: "choice-option" });
    label.htmlFor = optionId;
    append(label, input, element("span", { text: LABELS[value] }));
    choices.append(label);
  });
  fieldset.append(choices);
  return fieldset;
}

function sectionHeading(eyebrow, heading, description) {
  const wrapper = element("div");
  append(
    wrapper,
    element("p", { className: "eyebrow", text: eyebrow }),
    element("h3", { text: heading }),
    description
      ? element("p", { className: "muted", text: description })
      : null,
  );
  return wrapper;
}

function renderNoteChips(midiNotes) {
  const list = element("ul", { className: "note-chip-list" });
  midiNotes.forEach((midiNote) => {
    list.append(
      element("li", { className: "note-chip", text: midiNoteLabel(midiNote) }),
    );
  });
  return list;
}

function renderKeyboard(midiNotes, accessibleLabel = "Observed notes") {
  const sounding = new Set(midiNotes);
  const first = Math.floor(Math.min(...midiNotes) / 12) * 12;
  const last = Math.floor(Math.max(...midiNotes) / 12) * 12 + 11;
  const whitePitchClasses = new Set([0, 2, 4, 5, 7, 9, 11]);
  const whiteNotes = [];
  for (let midiNote = first; midiNote <= last; midiNote += 1) {
    if (whitePitchClasses.has(midiNote % 12)) whiteNotes.push(midiNote);
  }

  const keyboard = element("div", { className: "piano-keyboard" });
  keyboard.setAttribute("role", "img");
  keyboard.setAttribute(
    "aria-label",
    `${accessibleLabel}: ${formatNoteList(midiNotes)}`,
  );
  const whiteLayer = element("div", { className: "piano-white-keys" });
  whiteNotes.forEach((midiNote) => {
    const key = element("span", {
      className: `piano-key piano-key-white${sounding.has(midiNote) ? " sounding" : ""}`,
    });
    key.setAttribute("aria-hidden", "true");
    key.title = midiNoteLabel(midiNote);
    whiteLayer.append(key);
  });
  keyboard.append(whiteLayer);

  for (let midiNote = first; midiNote <= last; midiNote += 1) {
    if (whitePitchClasses.has(midiNote % 12)) continue;
    const whiteKeysBefore = whiteNotes.filter((note) => note < midiNote).length;
    const key = element("span", {
      className: `piano-key piano-key-black${sounding.has(midiNote) ? " sounding" : ""}`,
    });
    key.setAttribute("aria-hidden", "true");
    key.title = midiNoteLabel(midiNote);
    key.style.left = `${(whiteKeysBefore / whiteNotes.length) * 100}%`;
    key.style.width = `${(0.62 / whiteNotes.length) * 100}%`;
    keyboard.append(key);
  }
  return keyboard;
}

function renderGeneratedEvidence(evidence) {
  const wrapper = element("div");
  append(
    wrapper,
    element("h4", { text: "All observed notes" }),
    renderKeyboard(evidence.midiNotes),
    renderNoteChips(evidence.midiNotes),
  );

  if (evidence.onsetCohortsMs) {
    wrapper.append(element("h4", { text: "Recorded attacks" }));
    const onsetList = element("ol", { className: "onset-list" });
    evidence.onsetCohortsMs.forEach((cohort) => {
      const item = element("li");
      append(
        item,
        element("strong", { text: formatOnsetTime(cohort.time) }),
        renderNoteChips(cohort.midiNotes),
      );
      onsetList.append(item);
    });
    wrapper.append(onsetList);
  } else {
    wrapper.append(
      element("p", {
        className: "muted",
        text: "This case includes no timing or motion history.",
      }),
    );
  }

  return wrapper;
}

function renderScoreEvidence(evidence) {
  const source = evidence.source;
  const excerpt = scoreExcerptForEvidence(presentationManifest, evidence);
  const imageUrl = scoreAssetUrls.get(source.sourceIdentifier);
  if (!imageUrl) throw new Error("The verified score excerpt is unavailable.");

  const wrapper = element("div");
  const heading = element("h4", { text: source.work });
  const location = element("p", {
    className: "score-location",
    text: source.scoreLocation,
  });
  const edition = element("p", {
    className: "score-location",
    text: `Edition: ${source.edition}`,
  });
  const figure = element("figure", { className: "score-figure" });
  const image = element("img");
  image.src = imageUrl;
  image.alt = excerpt.asset.alt;
  image.width = excerpt.asset.width;
  image.height = excerpt.asset.height;
  const caption = element("figcaption", {
    text: "Excerpt from the source score. Open the complete score below for broader context.",
  });
  append(figure, image, caption);

  const sourceLink = element("a", { text: "Open the complete source score" });
  sourceLink.href = source.sourceUrl;
  sourceLink.target = "_blank";
  sourceLink.rel = "noopener noreferrer";
  const sourceParagraph = element("p");
  sourceParagraph.append(sourceLink);

  append(wrapper, heading, location, edition, figure, sourceParagraph);
  return wrapper;
}

function renderEvidence(reviewCase) {
  const section = element("section", { className: "case-section" });
  section.append(
    sectionHeading("Musical example", "Read or inspect the example"),
  );
  const card = element("div", { className: "evidence-card" });
  const evidence = reviewCase.evidence;
  card.append(
    evidence.kind === "synthetic-midi"
      ? renderGeneratedEvidence(evidence)
      : renderScoreEvidence(evidence),
  );
  section.append(card);
  return section;
}

function renderJudgments(caseIndex, response) {
  const section = element("section", { className: "case-section" });
  section.append(
    sectionHeading(
      "Your musical reading",
      "Choose the unit and construction",
      "Judge the construction here. Later questions ask whether each kind of musical information could support it.",
    ),
  );
  section.append(
    radioGroup({
      id: `case-${caseIndex}-observation`,
      legend: "What is the smallest musical unit needed for your judgment?",
      values: OBSERVATION_KINDS,
      selected: response.observationKind,
      help: "Choose one simultaneous sonority only when every note needed for the reading actually sounds at once.",
      onChange(value) {
        response.observationKind = value;
        responseChanged();
      },
    }),
    radioGroup({
      id: `case-${caseIndex}-tag`,
      legend: "Which statement best describes the construction?",
      values: CONSTRUCTION_TAGS,
      selected: response.constructionTag,
      help: "Cannot determine is preferable to forcing an unsupported answer.",
      onChange(value) {
        response.constructionTag = value;
        responseChanged();
      },
    }),
  );
  return section;
}

function derivedLayerSummary(layer) {
  const notes = layer.midiNotes?.length
    ? formatNoteList(layer.midiNotes)
    : "none assigned";
  const pitchClasses = layer.pitchClasses.length
    ? layer.pitchClasses.map(pitchClassLabel).join(", ")
    : "none yet";
  return `Assigned notes: ${notes}. Distinct pitch names: ${pitchClasses}.`;
}

function renderPitchClassChoices(
  caseIndex,
  layerIndex,
  layer,
  response,
  evidence,
) {
  const group = element("fieldset", {
    id: `case-${caseIndex}-layer-${layerIndex}-pitch-classes`,
    className: "choice-group",
  });
  group.append(element("legend", { text: "Notes in this layer" }));
  const grid = element("div", { className: "pitch-class-grid" });
  for (let pitchClass = 0; pitchClass < 12; pitchClass += 1) {
    const id = `case-${caseIndex}-layer-${layerIndex}-pc-${pitchClass}`;
    const input = element("input", { id });
    input.type = "checkbox";
    input.checked = layer.pitchClasses.includes(pitchClass);
    input.addEventListener("change", () => {
      if (input.checked) {
        layer.pitchClasses.push(pitchClass);
      } else {
        layer.pitchClasses = layer.pitchClasses.filter(
          (value) => value !== pitchClass,
        );
      }
      refreshDerivedFields(response, evidence);
      updateDerivedReadouts(caseIndex, response);
      responseChanged();
    });
    const label = element("label", { className: "pitch-class-option" });
    label.htmlFor = id;
    append(
      label,
      input,
      element("span", { text: PITCH_CLASS_LABELS[pitchClass] }),
    );
    grid.append(label);
  }
  append(
    group,
    element("p", {
      className: "help",
      text: "These choices are octave-neutral. Preserve the intended enharmonic spelling in the chord identity above.",
    }),
    grid,
  );
  return group;
}

function renderLayers(caseIndex, response, evidence) {
  const section = element("section", { className: "case-section" });
  const heading = element("div", { className: "layer-heading" });
  append(
    heading,
    sectionHeading(
      "Chordal description",
      "Name the layers and assign their notes",
      "The first two construction choices require at least two non-empty conventional chordal units.",
    ),
  );
  const addButton = element("button", {
    className: "button tertiary",
    text: "Add chordal layer",
  });
  addButton.type = "button";
  addButton.addEventListener("click", () => {
    addLayer(response, evidence);
    saveDraft();
    renderCase();
    document
      .querySelector(
        `#case-${caseIndex}-layer-${response.layers.length - 1}-identity`,
      )
      ?.focus();
  });
  heading.append(addButton);
  section.append(heading);

  const list = element("div", {
    id: `case-${caseIndex}-layers`,
    className: "layer-list",
  });
  if (response.layers.length === 0) {
    list.append(
      element("p", {
        className: "muted",
        text: "No layers added. This is valid for cannot determine and may be valid when a polychord reading would be misleading.",
      }),
    );
  }
  response.layers.forEach((layer, layerIndex) => {
    const card = element("fieldset", { className: "layer-card" });
    card.append(element("legend", { text: `Layer ${layerIndex + 1}` }));

    const identityField = element("div", { className: "field" });
    const identityId = `case-${caseIndex}-layer-${layerIndex}-identity`;
    const identityLabel = element("label", { text: "Chord identity" });
    identityLabel.htmlFor = identityId;
    const identityInput = element("input", { id: identityId });
    identityInput.type = "text";
    identityInput.value = layer.identity;
    identityInput.autocomplete = "off";
    identityInput.spellcheck = false;
    identityInput.addEventListener("input", () => {
      layer.identity = identityInput.value;
      responseChanged();
    });
    append(
      identityField,
      identityLabel,
      identityInput,
      element("p", {
        className: "help",
        text: "Use the concise chord notation you would normally write.",
      }),
    );
    card.append(identityField);

    if (evidence.kind === "synthetic-midi") {
      card.append(
        element("p", {
          id: `case-${caseIndex}-layer-${layerIndex}-summary`,
          className: "readout",
          text: derivedLayerSummary(layer),
        }),
      );
    } else {
      card.append(
        renderPitchClassChoices(
          caseIndex,
          layerIndex,
          layer,
          response,
          evidence,
        ),
      );
    }

    const actions = element("div", { className: "layer-actions" });
    const removeButton = element("button", {
      className: "text-button danger",
      text: `Remove layer ${layerIndex + 1}`,
    });
    removeButton.type = "button";
    removeButton.addEventListener("click", () => {
      try {
        removeLayer(response, evidence, layerIndex);
        saveDraft();
        renderCase();
      } catch (error) {
        setStatus(error.message, "error");
        document
          .querySelector(`#case-${caseIndex}-note-assignments select`)
          ?.focus();
      }
    });
    actions.append(removeButton);
    card.append(actions);
    list.append(card);
  });
  section.append(list);

  if (evidence.kind === "synthetic-midi") {
    const assignments = element("fieldset", {
      id: `case-${caseIndex}-note-assignments`,
      className: "choice-group",
    });
    assignments.append(element("legend", { text: "Assign each written note" }));
    assignments.append(
      element("p", {
        className: "help",
        text: "Assign each octave-specific note once, or leave it unassigned. Different octaves of the same pitch may belong to different layers.",
      }),
    );
    const rows = element("ul", { className: "note-assignment-list" });
    evidence.midiNotes.forEach((midiNote) => {
      const row = element("li", { className: "note-assignment-row" });
      const selectId = `case-${caseIndex}-midi-${midiNote}`;
      const label = element("label", {
        text: midiNoteLabel(midiNote),
      });
      label.htmlFor = selectId;
      const select = element("select", { id: selectId });
      const unassigned = element("option", { text: "Not assigned to a layer" });
      unassigned.value = "unassigned";
      select.append(unassigned);
      response.layers.forEach((_, layerIndex) => {
        const option = element("option", { text: `Layer ${layerIndex + 1}` });
        option.value = String(layerIndex);
        select.append(option);
      });
      select.value = midiDestination(response, midiNote);
      select.addEventListener("change", () => {
        assignMidiNote(response, evidence, midiNote, select.value);
        updateDerivedReadouts(caseIndex, response);
        responseChanged();
      });
      append(row, label, select);
      rows.append(row);
    });
    assignments.append(rows);
    section.append(assignments);
  }

  section.append(
    element("p", {
      id: `case-${caseIndex}-shared-summary`,
      className: "readout",
      text: `Notes used in more than one layer: ${response.sharedPitchClasses.map(pitchClassLabel).join(", ") || "none"}.`,
    }),
  );
  return section;
}

function updateDerivedReadouts(caseIndex, response) {
  response.layers.forEach((layer, layerIndex) => {
    const summary = document.querySelector(
      `#case-${caseIndex}-layer-${layerIndex}-summary`,
    );
    if (summary) summary.textContent = derivedLayerSummary(layer);
  });
  const shared = document.querySelector(`#case-${caseIndex}-shared-summary`);
  if (shared) {
    shared.textContent = `Notes used in more than one layer: ${response.sharedPitchClasses.map(pitchClassLabel).join(", ") || "none"}.`;
  }
}

function renderAlternatives(caseIndex, response) {
  const section = element("section", { className: "case-section" });
  const heading = element("div", { className: "layer-heading" });
  heading.append(
    sectionHeading(
      "Alternative reading",
      "Could one chord name this instead?",
      "List only plausible integrated single-chord readings. Leave this empty when none is defensible.",
    ),
  );
  const addButton = element("button", {
    className: "button tertiary",
    text: "Add alternative",
  });
  addButton.type = "button";
  addButton.addEventListener("click", () => {
    response.singleChordAlternatives.push("");
    saveDraft();
    renderCase();
    document
      .querySelector(
        `#case-${caseIndex}-alternative-${response.singleChordAlternatives.length - 1}`,
      )
      ?.focus();
  });
  heading.append(addButton);
  section.append(heading);

  const list = element("ul", { className: "alternative-list" });
  response.singleChordAlternatives.forEach((alternative, alternativeIndex) => {
    const row = element("li", { className: "alternative-row field" });
    const inputId = `case-${caseIndex}-alternative-${alternativeIndex}`;
    const label = element("label", {
      className: "field-label",
      text: `Alternative ${alternativeIndex + 1}`,
    });
    label.htmlFor = inputId;
    const input = element("input", { id: inputId });
    input.type = "text";
    input.value = alternative;
    input.addEventListener("input", () => {
      response.singleChordAlternatives[alternativeIndex] = input.value;
      responseChanged();
    });
    const removeButton = element("button", {
      className: "text-button danger",
      text: "Remove",
    });
    removeButton.type = "button";
    removeButton.setAttribute(
      "aria-label",
      `Remove alternative ${alternativeIndex + 1}`,
    );
    removeButton.addEventListener("click", () => {
      response.singleChordAlternatives.splice(alternativeIndex, 1);
      saveDraft();
      renderCase();
    });
    append(row, label, input, removeButton);
    list.append(row);
  });
  if (response.singleChordAlternatives.length === 0) {
    list.append(
      element("li", { className: "muted", text: "No alternatives added." }),
    );
  }
  section.append(list);
  return section;
}

function renderEligibility(caseIndex, response) {
  const section = element("section", { className: "case-section" });
  section.append(
    sectionHeading(
      "Available information",
      "Could each kind of information support your reading?",
      "Answer all three separately. This does not change the construction judgment above.",
    ),
  );
  const list = element("div", { className: "eligibility-list" });
  INPUT_CONDITIONS.forEach((input) => {
    const judgment = response.inputEligibility[input];
    const card = element("section", { className: "eligibility-card" });
    card.append(
      element("h4", { text: LABELS[input] }),
      element("p", { className: "help input-help", text: INPUT_HELP[input] }),
    );
    const grid = element("div", { className: "eligibility-grid" });

    const statusField = element("div", { className: "field" });
    const statusId = `case-${caseIndex}-${input}-status`;
    const statusLabel = element("label", {
      text: "How well does this support your reading?",
    });
    statusLabel.htmlFor = statusId;
    const select = element("select", { id: statusId });
    const placeholder = element("option", { text: "Choose a judgment" });
    placeholder.value = "";
    select.append(placeholder);
    ELIGIBILITY_STATUSES.forEach((status) => {
      const option = element("option", { text: LABELS[status] });
      option.value = status;
      select.append(option);
    });
    select.value = judgment.status ?? "";
    select.addEventListener("change", () => {
      judgment.status = select.value || null;
      responseChanged();
    });
    append(statusField, statusLabel, select);

    const reasonField = element("div", { className: "field" });
    const reasonId = `case-${caseIndex}-${input}-reason`;
    const reasonLabel = element("label", { text: "Musical reason" });
    reasonLabel.htmlFor = reasonId;
    const reason = element("textarea", { id: reasonId });
    reason.rows = 3;
    reason.value = judgment.reason;
    reason.addEventListener("input", () => {
      judgment.reason = reason.value;
      responseChanged();
    });
    append(reasonField, reasonLabel, reason);
    append(grid, statusField, reasonField);
    card.append(grid);
    list.append(card);
  });
  section.append(list);
  return section;
}

function renderConfidenceAndNotes(caseIndex, response) {
  const section = element("section", { className: "case-section" });
  section.append(sectionHeading("Reflection", "Confidence and final notes"));
  section.append(
    radioGroup({
      id: `case-${caseIndex}-confidence`,
      legend: "Confidence",
      values: CONFIDENCE_LEVELS,
      selected: response.confidence,
      help: "Report confidence in your construction judgment. Still explain each answer above.",
      onChange(value) {
        response.confidence = value;
        responseChanged();
      },
    }),
  );
  const notesField = element("div", { className: "field" });
  const notesId = `case-${caseIndex}-notes`;
  const label = element("label", { text: "Additional notes (optional)" });
  label.htmlFor = notesId;
  const textarea = element("textarea", { id: notesId });
  textarea.rows = 5;
  textarea.value = response.notes;
  textarea.addEventListener("input", () => {
    response.notes = textarea.value;
    responseChanged();
  });
  append(
    notesField,
    label,
    textarea,
    element("p", {
      className: "help",
      text: "Record ambiguity, a choice missing from the guide, a case-specific reference, or other evidence that influenced the judgment.",
    }),
  );
  section.append(notesField);
  return section;
}

function renderWorkedExamples() {
  orientationExamples.replaceChildren();
  ORIENTATION_EXAMPLES.forEach((example, exampleIndex) => {
    const article = element("article", { className: "worked-example" });
    append(
      article,
      element("p", {
        className: "worked-example-number",
        text: `Worked example ${exampleIndex + 1}`,
      }),
      element("h3", { text: example.title }),
      element("p", { text: example.description }),
      renderKeyboard(example.midiNotes, `Worked example ${exampleIndex + 1}`),
      renderNoteChips(example.midiNotes),
    );
    const answer = element("p", { className: "worked-answer" });
    append(
      answer,
      element("strong", { text: "Worked judgment: " }),
      document.createTextNode(example.answer),
    );
    append(article, answer, element("p", { text: example.explanation }));
    orientationExamples.append(article);
  });
}

function renderReadinessQuestions() {
  readinessQuestions.replaceChildren();
  READINESS_QUESTIONS.forEach((question) => {
    const fieldset = element("fieldset", {
      id: `readiness-${question.id}`,
      className: "choice-group readiness-question",
    });
    fieldset.append(element("legend", { text: question.legend }));
    const choices = element("div", { className: "choice-list" });
    question.options.forEach((option) => {
      const optionId = `readiness-${question.id}-${option.value}`;
      const input = element("input", { id: optionId });
      input.type = "radio";
      input.name = `readiness-${question.id}`;
      input.value = option.value;
      const label = element("label", { className: "choice-option" });
      label.htmlFor = optionId;
      append(label, input, element("span", { text: option.label }));
      choices.append(label);
    });
    fieldset.append(choices);
    readinessQuestions.append(fieldset);
  });
}

function showReviewWorkspace({ focus = false } = {}) {
  orientationPanel.hidden = true;
  reviewWorkspace.hidden = false;
  if (focus) {
    const target = state.annotatorId
      ? document.querySelector("#current-case-heading")
      : annotatorIdInput;
    target?.focus();
    target?.scrollIntoView({ behavior: "smooth", block: "start" });
  }
}

function showOrientation({ focus = false } = {}) {
  reviewWorkspace.hidden = true;
  orientationPanel.hidden = false;
  if (focus) {
    document.querySelector("#orientation-heading")?.focus();
    orientationPanel.scrollIntoView({ behavior: "smooth", block: "start" });
  }
}

function wireOrientation() {
  readinessForm.addEventListener("submit", (event) => {
    event.preventDefault();
    readinessQuestions
      .querySelectorAll(".readiness-feedback")
      .forEach((node) => node.remove());
    readinessQuestions
      .querySelectorAll('[aria-invalid="true"]')
      .forEach((node) => node.removeAttribute("aria-invalid"));

    const formData = new FormData(readinessForm);
    const answers = Object.fromEntries(
      READINESS_QUESTIONS.map((question) => [
        question.id,
        formData.get(`readiness-${question.id}`),
      ]),
    );

    if (!readinessIsComplete(answers)) {
      let firstIncorrect;
      READINESS_QUESTIONS.forEach((question) => {
        if (answers[question.id] === question.correct) return;
        const fieldset = document.querySelector(`#readiness-${question.id}`);
        fieldset.setAttribute("aria-invalid", "true");
        fieldset.append(
          element("p", {
            className: "field-error readiness-feedback",
            text: `Review this boundary. The guide's answer is: ${question.options.find((option) => option.value === question.correct).label}`,
          }),
        );
        firstIncorrect ??= fieldset;
      });
      readinessMessage.textContent =
        "The orientation is not complete yet. Review the marked task boundaries and try again.";
      readinessMessage.hidden = false;
      firstIncorrect?.scrollIntoView({ behavior: "smooth", block: "center" });
      firstIncorrect?.querySelector("input")?.focus();
      return;
    }

    readinessMessage.hidden = true;
    state.orientationComplete = true;
    persistDraft(false);
    showReviewWorkspace({ focus: true });
    setStatus(
      "Orientation complete. The six review cases are now available.",
      "success",
    );
  });
}

async function prepareScoreAssets() {
  assertPresentationManifest(presentationManifest);
  for (const reviewCase of template.cases) {
    if (reviewCase.evidence.kind !== "score-source") continue;
    const excerpt = scoreExcerptForEvidence(
      presentationManifest,
      reviewCase.evidence,
    );
    if (!/^[A-Za-z0-9._-]+$/.test(excerpt.asset.file)) {
      throw new Error("A score-excerpt asset path is invalid.");
    }
    const sourceIdentifier = reviewCase.evidence.source.sourceIdentifier;
    if (scoreAssetUrls.has(sourceIdentifier)) continue;
    scoreAssetUrls.set(
      sourceIdentifier,
      await loadPinnedImage(
        `assets/${excerpt.asset.file}`,
        excerpt.asset.sha256,
        `${reviewCase.evidence.source.work} score excerpt`,
      ),
    );
  }
}

function navigateTo(caseIndex, focus = true) {
  state.currentCaseIndex = caseIndex;
  saveDraft();
  renderNavigation();
  renderCase();
  if (focus) {
    document.querySelector("#current-case-heading")?.focus();
  }
}

function renderCaseActions(caseIndex) {
  const actions = element("div", { className: "case-actions" });
  const previous = element("button", {
    className: "button tertiary",
    text: "Previous case",
  });
  previous.type = "button";
  previous.disabled = caseIndex === 0;
  previous.addEventListener("click", () => navigateTo(caseIndex - 1));
  const next = element("button", {
    className: "button primary",
    text: "Next case",
  });
  next.type = "button";
  next.disabled = caseIndex === template.cases.length - 1;
  next.addEventListener("click", () => navigateTo(caseIndex + 1));
  append(actions, previous, next);
  return actions;
}

function renderCase() {
  const caseIndex = state.currentCaseIndex;
  const reviewCase = template.cases[caseIndex];
  const response = state.responses[caseIndex];
  casePanel.replaceChildren();

  const header = element("header", { className: "case-header" });
  const heading = element("h2", {
    id: "current-case-heading",
    text: `Case ${caseIndex + 1}`,
  });
  heading.tabIndex = -1;
  append(header, heading);
  append(
    casePanel,
    header,
    renderEvidence(reviewCase),
    renderJudgments(caseIndex, response),
    renderLayers(caseIndex, response, reviewCase.evidence),
    renderAlternatives(caseIndex, response),
    renderEligibility(caseIndex, response),
    renderConfidenceAndNotes(caseIndex, response),
    renderCaseActions(caseIndex),
  );
  decorateErrors();
}

function renderNavigation() {
  navigationList.replaceChildren();
  let completeCount = 0;
  template.cases.forEach((reviewCase, caseIndex) => {
    const complete = caseIsComplete(template, state, caseIndex);
    if (complete) completeCount += 1;
    const item = element("li");
    const button = element("button", {
      className: `case-nav-button${complete ? " complete" : ""}`,
      text: `Case ${caseIndex + 1}`,
    });
    button.type = "button";
    button.setAttribute(
      "aria-label",
      `Case ${caseIndex + 1}, ${complete ? "complete" : "incomplete"}`,
    );
    if (caseIndex === state.currentCaseIndex) {
      button.setAttribute("aria-current", "step");
    }
    button.addEventListener("click", () => navigateTo(caseIndex));
    item.append(button);
    navigationList.append(item);
  });
  progressSummary.textContent = `${completeCount} of ${template.cases.length} complete`;
}

function decorateErrors() {
  reviewForm.querySelectorAll(".field-error").forEach((node) => node.remove());
  reviewForm.querySelectorAll('[aria-invalid="true"]').forEach((node) => {
    node.removeAttribute("aria-invalid");
    const describedBy = (node.getAttribute("aria-describedby") ?? "")
      .split(" ")
      .filter((id) => !id.endsWith("-error"));
    if (describedBy.length)
      node.setAttribute("aria-describedby", describedBy.join(" "));
    else node.removeAttribute("aria-describedby");
  });

  const grouped = new Map();
  visibleErrors
    .filter(
      (error) =>
        error.caseIndex === null || error.caseIndex === state.currentCaseIndex,
    )
    .forEach((error) => {
      const messages = grouped.get(error.fieldId) ?? [];
      messages.push(error.message);
      grouped.set(error.fieldId, messages);
    });

  grouped.forEach((messages, fieldId) => {
    const field = document.getElementById(fieldId);
    if (!field) return;
    const errorId = `${fieldId}-error`;
    field.setAttribute("aria-invalid", "true");
    const describedBy = new Set(
      (field.getAttribute("aria-describedby") ?? "").split(" "),
    );
    describedBy.delete("");
    describedBy.add(errorId);
    field.setAttribute("aria-describedby", [...describedBy].join(" "));
    const insertionTarget = field.closest(".inline-control") ?? field;
    insertionTarget.insertAdjacentElement(
      "afterend",
      element("p", {
        id: errorId,
        className: "field-error",
        text: messages.join(" "),
      }),
    );
  });
}

function focusError(error) {
  if (error.caseIndex !== null && error.caseIndex !== state.currentCaseIndex) {
    navigateTo(error.caseIndex, false);
  }
  document.getElementById(error.fieldId)?.focus();
}

function showErrors(errors) {
  visibleErrors = errors;
  errorList.replaceChildren();
  errors.forEach((error) => {
    const item = element("li");
    const button = element("button", {
      className: "error-link",
      text: `${error.caseIndex === null ? "Review details" : `Case ${error.caseIndex + 1}`}: ${error.message}`,
    });
    button.type = "button";
    button.addEventListener("click", () => focusError(error));
    item.append(button);
    errorList.append(item);
  });
  errorSummary.hidden = false;
  decorateErrors();
  errorSummary.scrollIntoView({ behavior: "smooth", block: "start" });
  errorSummary.focus();
}

function downloadCompletedPacket(completed) {
  const serialized = `${JSON.stringify(completed, null, 2)}\n`;
  const blob = new Blob([serialized], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = element("a");
  anchor.href = url;
  anchor.download = `pilot-v0-${state.annotatorId}.json`;
  document.body.append(anchor);
  anchor.click();
  anchor.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function wireStaticControls() {
  annotatorIdInput.value = state.annotatorId;
  completedOnInput.value = state.completedOn;
  annotatorIdInput.addEventListener("input", () => {
    state.annotatorId = annotatorIdInput.value;
    saveDraft();
  });
  completedOnInput.addEventListener("change", () => {
    state.completedOn = completedOnInput.value;
    saveDraft();
  });
  generateIdButton.addEventListener("click", () => {
    const random = new Uint32Array(2);
    crypto.getRandomValues(random);
    state.annotatorId = `reviewer-${[...random]
      .map((value) => value.toString(16).padStart(8, "0"))
      .join("")}`;
    annotatorIdInput.value = state.annotatorId;
    saveDraft();
    annotatorIdInput.focus();
  });
  clearDraftButton.addEventListener("click", () => {
    if (!window.confirm("Clear every answer saved in this browser?")) {
      return;
    }
    if (storageAvailable) {
      try {
        localStorage.removeItem(STORAGE_KEY);
      } catch {
        storageAvailable = false;
      }
    }
    state = createInstrumentState(template);
    visibleErrors = [];
    readinessForm.reset();
    readinessMessage.hidden = true;
    readinessQuestions
      .querySelectorAll(".readiness-feedback")
      .forEach((node) => node.remove());
    readinessQuestions
      .querySelectorAll('[aria-invalid="true"]')
      .forEach((node) => node.removeAttribute("aria-invalid"));
    annotatorIdInput.value = "";
    completedOnInput.value = "";
    errorSummary.hidden = true;
    renderNavigation();
    renderCase();
    showOrientation({ focus: true });
    setStatus("Saved answers cleared.", "success");
  });
  reviewForm.addEventListener("submit", (event) => {
    event.preventDefault();
    state.annotatorId = annotatorIdInput.value;
    state.completedOn = completedOnInput.value;
    try {
      const completed = buildCompletedPacket(template, state);
      visibleErrors = [];
      errorSummary.hidden = true;
      decorateErrors();
      persistDraft(false);
      downloadCompletedPacket(completed);
      setStatus("Your completed review was downloaded.", "success");
    } catch (error) {
      if (!(error instanceof InstrumentValidationError)) throw error;
      showErrors(error.errors);
      setStatus(
        "The response was not downloaded because required answers remain.",
        "error",
      );
    }
  });
}

async function start() {
  const packetText = await loadPinnedText(
    PACKET_PATH,
    EXPECTED_PACKET_SHA256,
    "Review materials",
  );
  template = JSON.parse(packetText);
  await loadPinnedText(
    GUIDE_PATH,
    template.annotationGuide.sha256,
    "Annotation guide",
  );
  const presentationText = await loadPinnedText(
    PRESENTATION_PATH,
    EXPECTED_PRESENTATION_SHA256,
    "Score-excerpt manifest",
  );
  presentationManifest = JSON.parse(presentationText);
  await prepareScoreAssets();

  state = recoverDraft(createInstrumentState(template));
  loadingPanel.hidden = true;
  instrument.hidden = false;
  renderWorkedExamples();
  renderReadinessQuestions();
  wireOrientation();
  wireStaticControls();
  renderNavigation();
  renderCase();
  if (state.orientationComplete) {
    showReviewWorkspace();
  } else {
    showOrientation();
  }
}

window.addEventListener("beforeunload", () => {
  scoreAssetUrls.forEach((url) => URL.revokeObjectURL(url));
});

start().catch((error) => {
  loadingPanel.hidden = true;
  loadErrorPanel.hidden = false;
  loadErrorMessage.textContent = error.message;
  setStatus("Review unavailable.", "error");
});
