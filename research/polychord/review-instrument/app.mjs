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

const EXPECTED_PACKET_SHA256 =
  "8eb672bf73ba7dea9eb781bd3c1886b0542030104c24915399e78a92986c70fa";
const PACKET_PATH = "../pilot-review-template-v0.json";
const GUIDE_PATH = "../pilot-annotation.md";
const STORAGE_KEY = `${INSTRUMENT_VERSION}:${EXPECTED_PACKET_SHA256}`;

const LABELS = {
  snapshot: "Snapshot",
  "event-window": "Event window",
  positive: "Positive",
  boundary: "Boundary",
  "negative-guard": "Negative guard",
  abstain: "Abstain",
  low: "Low",
  medium: "Medium",
  high: "High",
  eligible: "Eligible",
  ambiguous: "Ambiguous",
  ineligible: "Ineligible",
  "research-candidate": "Research candidate",
  unknown: "Unknown",
  adjacentRegisterSnapshot: "Adjacent-register snapshot",
  pitchRegisterSnapshot: "General pitch-and-register snapshot",
  timestampedEventStream: "Timestamped event stream",
};

const loadingPanel = document.querySelector("#loading-panel");
const loadErrorPanel = document.querySelector("#load-error");
const loadErrorMessage = document.querySelector("#load-error-message");
const instrument = document.querySelector("#instrument");
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
const instrumentVersion = document.querySelector("#instrument-version");
const packetDigest = document.querySelector("#packet-digest");

let template;
let state;
let visibleErrors = [];
let saveTimer;
let storageAvailable = true;

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

async function sha256(text) {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function loadPinnedText(path, expectedDigest, description) {
  const response = await fetch(path, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`${description} returned HTTP ${response.status}.`);
  }
  const text = await response.text();
  const actualDigest = await sha256(text);
  if (actualDigest !== expectedDigest) {
    throw new Error(
      `${description} digest mismatch: expected ${expectedDigest}, received ${actualDigest}.`,
    );
  }
  return text;
}

function recoverDraft(freshState) {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (!saved) return freshState;
    const candidate = JSON.parse(saved);
    if (
      candidate.instrumentVersion !== INSTRUMENT_VERSION ||
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
    setStatus("Recovered the draft saved in this browser.");
    return candidate;
  } catch {
    try {
      localStorage.removeItem(STORAGE_KEY);
      setStatus("Discarded an incompatible local draft.", "error");
    } catch {
      storageAvailable = false;
      setStatus(
        "Browser storage is unavailable. Keep this page open until you export.",
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
    if (announce) setStatus("Draft saved in this browser.");
  } catch {
    storageAvailable = false;
    setStatus(
      "Browser storage is unavailable. Keep this page open until you export.",
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

function renderEvidence(reviewCase) {
  const section = element("section", { className: "case-section" });
  section.append(sectionHeading("Pinned input", "Evidence"));
  const card = element("div", { className: "evidence-card" });
  const evidence = reviewCase.evidence;

  if (evidence.kind === "synthetic-midi") {
    append(
      card,
      element("p", {
        text: `MIDI notes: ${evidence.midiNotes.join(", ")}`,
        className: "data-value",
      }),
    );
    if (evidence.onsetCohortsMs) {
      const heading = element("h4", { text: "Onset cohorts" });
      const list = element("ul");
      evidence.onsetCohortsMs.forEach((cohort) => {
        list.append(
          element("li", {
            text: `${cohort.time} ms: MIDI ${cohort.midiNotes.join(", ")}`,
            className: "data-value",
          }),
        );
      });
      append(card, heading, list);
    } else {
      card.append(
        element("p", {
          className: "muted",
          text: "No onset-cohort evidence is present in this packet.",
        }),
      );
    }
  } else {
    const source = evidence.source;
    const definitions = element("dl");
    const rows = [
      ["Work", source.work],
      ["Edition", source.edition],
      ["Location", source.scoreLocation],
      ["Source ID", source.sourceIdentifier],
      ["SHA-256", source.sha256],
    ];
    rows.forEach(([term, value]) => {
      append(
        definitions,
        element("dt", { text: term }),
        element("dd", {
          text: value,
          className: term === "SHA-256" ? "data-value" : "",
        }),
      );
    });
    const sourceLink = element("a", { text: "Open pinned score source" });
    sourceLink.href = source.sourceUrl;
    sourceLink.target = "_blank";
    sourceLink.rel = "noopener noreferrer";
    const sourceParagraph = element("p");
    sourceParagraph.append(sourceLink);
    append(card, definitions, sourceParagraph);
  }
  section.append(card);
  return section;
}

function renderJudgments(caseIndex, response) {
  const section = element("section", { className: "case-section" });
  section.append(
    sectionHeading(
      "Construction",
      "Observation and construction tags",
      "Judge the construction separately from what each input representation can recover.",
    ),
  );
  section.append(
    radioGroup({
      id: `case-${caseIndex}-observation`,
      legend: "Observation unit",
      values: OBSERVATION_KINDS,
      selected: response.observationKind,
      help: "Choose snapshot only when the assigned notes actually sound together.",
      onChange(value) {
        response.observationKind = value;
        responseChanged();
      },
    }),
    radioGroup({
      id: `case-${caseIndex}-tag`,
      legend: "Construction tag",
      values: CONSTRUCTION_TAGS,
      selected: response.constructionTag,
      help: "Abstain is preferable to forcing an unsupported tag.",
      onChange(value) {
        response.constructionTag = value;
        responseChanged();
      },
    }),
  );
  return section;
}

function derivedLayerSummary(layer) {
  const midi = layer.midiNotes?.length ? layer.midiNotes.join(", ") : "none";
  const pitchClasses = layer.pitchClasses.length
    ? layer.pitchClasses.join(", ")
    : "none";
  return `Assigned MIDI: ${midi}. Derived pitch classes: ${pitchClasses}.`;
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
  group.append(element("legend", { text: "Pitch classes" }));
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
    append(label, input, element("span", { text: String(pitchClass) }));
    grid.append(label);
  }
  append(
    group,
    element("p", {
      className: "help",
      text: "Use pitch-class integers 0-11; enharmonic spelling remains in the identity text.",
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
      "Decomposition",
      "Layers and note assignment",
      "Positive and boundary tags require at least two non-empty conventional chordal units.",
    ),
  );
  const addButton = element("button", {
    className: "button tertiary",
    text: "Add layer",
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
        text: "No layers added. This is valid for abstain and may be valid for a negative guard.",
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
        text: "Enter your own concise identity; no chord-name normalization is applied.",
      }),
    );
    card.append(identityField);

    if (evidence.kind === "synthetic-midi") {
      card.append(
        element("p", {
          id: `case-${caseIndex}-layer-${layerIndex}-summary`,
          className: "readout data-value",
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
    assignments.append(element("legend", { text: "MIDI note assignment" }));
    assignments.append(
      element("p", {
        className: "help",
        text: "Assign each observed note exactly once. Pitch classes are derived from this assignment.",
      }),
    );
    const rows = element("ul", { className: "note-assignment-list" });
    evidence.midiNotes.forEach((midiNote) => {
      const row = element("li", { className: "note-assignment-row" });
      const selectId = `case-${caseIndex}-midi-${midiNote}`;
      const label = element("label", {
        text: `MIDI ${midiNote} · pitch class ${midiNote % 12}`,
      });
      label.htmlFor = selectId;
      const select = element("select", { id: selectId });
      const unassigned = element("option", { text: "Unassigned" });
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
      className: "readout data-value",
      text: `Shared pitch classes: ${response.sharedPitchClasses.join(", ") || "none"}.`,
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
    shared.textContent = `Shared pitch classes: ${response.sharedPitchClasses.join(", ") || "none"}.`;
  }
}

function renderAlternatives(caseIndex, response) {
  const section = element("section", { className: "case-section" });
  const heading = element("div", { className: "layer-heading" });
  heading.append(
    sectionHeading(
      "Alternative reading",
      "Integrated single-chord alternatives",
      "Record only alternatives to the proposed layering; leave the list empty when none is defensible.",
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
      "Recoverability",
      "Input eligibility",
      "Judge each input condition separately and explain every status, including unknown.",
    ),
  );
  const list = element("div", { className: "eligibility-list" });
  INPUT_CONDITIONS.forEach((input) => {
    const judgment = response.inputEligibility[input];
    const card = element("section", { className: "eligibility-card" });
    card.append(element("h4", { text: LABELS[input] }));
    const grid = element("div", { className: "eligibility-grid" });

    const statusField = element("div", { className: "field" });
    const statusId = `case-${caseIndex}-${input}-status`;
    const statusLabel = element("label", { text: "Status" });
    statusLabel.htmlFor = statusId;
    const select = element("select", { id: statusId });
    const placeholder = element("option", { text: "Choose status" });
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
    const reasonLabel = element("label", { text: "Reason" });
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
  section.append(sectionHeading("Reflection", "Confidence and notes"));
  section.append(
    radioGroup({
      id: `case-${caseIndex}-confidence`,
      legend: "Confidence",
      values: CONFIDENCE_LEVELS,
      selected: response.confidence,
      help: "Confidence is descriptive and does not replace eligibility reasons.",
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
      text: "Record ambiguity, missing rubric choices, or evidence that influenced the judgment.",
    }),
  );
  section.append(notesField);
  return section;
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
  append(
    header,
    heading,
    element("p", { className: "data-value", text: reviewCase.reviewId }),
  );
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
      text: `${error.caseIndex === null ? "Review metadata" : `Case ${error.caseIndex + 1}`}: ${error.message}`,
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
    if (
      !window.confirm(
        "Clear every answer saved by this instrument on this device?",
      )
    ) {
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
    annotatorIdInput.value = "";
    completedOnInput.value = "";
    errorSummary.hidden = true;
    renderNavigation();
    renderCase();
    setStatus("Local draft cleared.", "success");
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
      setStatus(
        "Response validated and downloaded. Keep this raw file unchanged.",
        "success",
      );
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
  instrumentVersion.textContent = INSTRUMENT_VERSION;
  packetDigest.textContent = EXPECTED_PACKET_SHA256;

  const packetText = await loadPinnedText(
    PACKET_PATH,
    EXPECTED_PACKET_SHA256,
    "Review packet",
  );
  template = JSON.parse(packetText);
  await loadPinnedText(
    GUIDE_PATH,
    template.annotationGuide.sha256,
    "Annotation guide",
  );

  state = recoverDraft(createInstrumentState(template));
  loadingPanel.hidden = true;
  instrument.hidden = false;
  wireStaticControls();
  renderNavigation();
  renderCase();
}

start().catch((error) => {
  loadingPanel.hidden = true;
  loadErrorPanel.hidden = false;
  loadErrorMessage.textContent = error.message;
  setStatus("Review instrument unavailable.", "error");
});
