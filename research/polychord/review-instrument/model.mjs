export const INSTRUMENT_VERSION = "polychord-pilot-review-instrument/1";
export const REVIEW_SCHEMA = "polychord-pilot-review/1";

export const CONSTRUCTION_TAGS = [
  "positive",
  "boundary",
  "negative-guard",
  "abstain",
];
export const OBSERVATION_KINDS = ["snapshot", "event-window"];
export const CONFIDENCE_LEVELS = ["low", "medium", "high"];
export const ELIGIBILITY_STATUSES = [
  "eligible",
  "ambiguous",
  "ineligible",
  "research-candidate",
  "unknown",
];
export const INPUT_CONDITIONS = [
  "adjacentRegisterSnapshot",
  "pitchRegisterSnapshot",
  "timestampedEventStream",
];

const ANNOTATOR_ID = /^[A-Za-z0-9][A-Za-z0-9._-]{2,63}$/;

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function sortedNumbers(values) {
  return [...values].sort((left, right) => left - right);
}

function uniquePitchClasses(midiNotes) {
  return sortedNumbers(new Set(midiNotes.map((note) => note % 12)));
}

function sharedPitchClasses(layers) {
  const shared = new Set();
  for (let left = 0; left < layers.length; left += 1) {
    for (let right = left + 1; right < layers.length; right += 1) {
      const rightPitchClasses = new Set(layers[right].pitchClasses);
      for (const pitchClass of layers[left].pitchClasses) {
        if (rightPitchClasses.has(pitchClass)) {
          shared.add(pitchClass);
        }
      }
    }
  }
  return sortedNumbers(shared);
}

function validIsoDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const parsed = new Date(`${value}T00:00:00Z`);
  return (
    !Number.isNaN(parsed.valueOf()) &&
    parsed.toISOString().slice(0, 10) === value
  );
}

export function assertTemplate(template) {
  if (template.schema !== REVIEW_SCHEMA || template.status !== "template") {
    throw new Error(
      "The review packet does not use the frozen template schema.",
    );
  }
  if (!Array.isArray(template.cases) || template.cases.length === 0) {
    throw new Error("The review packet does not contain any cases.");
  }
  for (const reviewCase of template.cases) {
    if (
      typeof reviewCase.reviewId !== "string" ||
      typeof reviewCase.evidence !== "object" ||
      typeof reviewCase.response !== "object"
    ) {
      throw new Error("The review packet contains a malformed case.");
    }
  }
}

export function createInstrumentState(template) {
  assertTemplate(template);
  return {
    instrumentVersion: INSTRUMENT_VERSION,
    annotatorId: "",
    completedOn: "",
    currentCaseIndex: 0,
    responses: template.cases.map((reviewCase) => {
      const response = clone(reviewCase.response);
      if (reviewCase.evidence.kind === "synthetic-midi") {
        response.unassignedMidiNotes = [...reviewCase.evidence.midiNotes];
      }
      return response;
    }),
  };
}

export function addLayer(response, evidence) {
  const layer = { identity: "", pitchClasses: [] };
  if (evidence.kind === "synthetic-midi") {
    layer.midiNotes = [];
  }
  response.layers.push(layer);
  refreshDerivedFields(response, evidence);
}

export function removeLayer(response, evidence, layerIndex) {
  const layer = response.layers[layerIndex];
  if (!layer) {
    throw new RangeError("Unknown layer index.");
  }
  if (layer.midiNotes?.length) {
    throw new Error("Reassign this layer's MIDI notes before removing it.");
  }
  response.layers.splice(layerIndex, 1);
  refreshDerivedFields(response, evidence);
}

export function assignMidiNote(response, evidence, midiNote, destination) {
  if (
    evidence.kind !== "synthetic-midi" ||
    !evidence.midiNotes.includes(midiNote)
  ) {
    throw new Error("The selected MIDI note is not part of this case.");
  }

  for (const layer of response.layers) {
    layer.midiNotes = layer.midiNotes.filter((note) => note !== midiNote);
  }
  response.unassignedMidiNotes = response.unassignedMidiNotes.filter(
    (note) => note !== midiNote,
  );

  if (destination === "unassigned") {
    response.unassignedMidiNotes.push(midiNote);
  } else {
    const layerIndex = Number(destination);
    if (!Number.isInteger(layerIndex) || !response.layers[layerIndex]) {
      throw new Error("The selected layer does not exist.");
    }
    response.layers[layerIndex].midiNotes.push(midiNote);
  }
  refreshDerivedFields(response, evidence);
}

export function refreshDerivedFields(response, evidence) {
  if (evidence.kind === "synthetic-midi") {
    for (const layer of response.layers) {
      layer.midiNotes = sortedNumbers(layer.midiNotes ?? []);
      layer.pitchClasses = uniquePitchClasses(layer.midiNotes);
    }
    response.unassignedMidiNotes = sortedNumbers(response.unassignedMidiNotes);
  } else {
    response.unassignedMidiNotes = [];
    for (const layer of response.layers) {
      delete layer.midiNotes;
      layer.pitchClasses = sortedNumbers(layer.pitchClasses ?? []);
    }
  }
  response.sharedPitchClasses = sharedPitchClasses(response.layers);
}

export function midiDestination(response, midiNote) {
  const layerIndex = response.layers.findIndex((layer) =>
    layer.midiNotes?.includes(midiNote),
  );
  return layerIndex === -1 ? "unassigned" : String(layerIndex);
}

function canonicalResponse(response, evidence) {
  const copy = clone(response);
  refreshDerivedFields(copy, evidence);
  return {
    observationKind: copy.observationKind,
    constructionTag: copy.constructionTag,
    layers: copy.layers.map((layer) => ({
      identity: layer.identity,
      ...(evidence.kind === "synthetic-midi"
        ? { midiNotes: sortedNumbers(layer.midiNotes) }
        : {}),
      pitchClasses: sortedNumbers(layer.pitchClasses),
    })),
    sharedPitchClasses: sortedNumbers(copy.sharedPitchClasses),
    unassignedMidiNotes: sortedNumbers(copy.unassignedMidiNotes),
    singleChordAlternatives: [...copy.singleChordAlternatives],
    inputEligibility: Object.fromEntries(
      INPUT_CONDITIONS.map((input) => [
        input,
        {
          status: copy.inputEligibility[input].status,
          reason: copy.inputEligibility[input].reason,
        },
      ]),
    ),
    confidence: copy.confidence,
    notes: copy.notes,
  };
}

function issue(errors, caseIndex, fieldId, message) {
  errors.push({ caseIndex, fieldId, message });
}

function validateCase(response, evidence, caseIndex, errors) {
  const prefix = `case-${caseIndex}`;
  if (!OBSERVATION_KINDS.includes(response.observationKind)) {
    issue(
      errors,
      caseIndex,
      `${prefix}-observation`,
      "Choose an observation unit.",
    );
  }
  if (!CONSTRUCTION_TAGS.includes(response.constructionTag)) {
    issue(errors, caseIndex, `${prefix}-tag`, "Choose a construction tag.");
  }
  if (!CONFIDENCE_LEVELS.includes(response.confidence)) {
    issue(
      errors,
      caseIndex,
      `${prefix}-confidence`,
      "Choose a confidence level.",
    );
  }

  if (
    ["positive", "boundary"].includes(response.constructionTag) &&
    response.layers.length < 2
  ) {
    issue(
      errors,
      caseIndex,
      `${prefix}-layers`,
      "Positive and boundary responses require at least two layers.",
    );
  }
  if (
    response.constructionTag === "negative-guard" &&
    response.layers.length > 1
  ) {
    issue(
      errors,
      caseIndex,
      `${prefix}-layers`,
      "A negative guard may contain at most one integrated layer.",
    );
  }

  response.layers.forEach((layer, layerIndex) => {
    if (typeof layer.identity !== "string" || layer.identity.trim() === "") {
      issue(
        errors,
        caseIndex,
        `${prefix}-layer-${layerIndex}-identity`,
        `Layer ${layerIndex + 1} needs an identity.`,
      );
    }
    if (!Array.isArray(layer.pitchClasses) || layer.pitchClasses.length === 0) {
      issue(
        errors,
        caseIndex,
        `${prefix}-layer-${layerIndex}-pitch-classes`,
        `Layer ${layerIndex + 1} needs at least one pitch class.`,
      );
    }
    if (
      evidence.kind === "synthetic-midi" &&
      (!Array.isArray(layer.midiNotes) || layer.midiNotes.length === 0)
    ) {
      issue(
        errors,
        caseIndex,
        `${prefix}-note-assignments`,
        `Layer ${layerIndex + 1} needs at least one assigned MIDI note.`,
      );
    }
  });

  if (evidence.kind === "synthetic-midi") {
    const assigned = response.layers.flatMap((layer) => layer.midiNotes ?? []);
    const accounted = [...assigned, ...response.unassignedMidiNotes];
    const unique = new Set(accounted);
    const expected = sortedNumbers(evidence.midiNotes);
    if (
      unique.size !== accounted.length ||
      JSON.stringify(sortedNumbers(accounted)) !== JSON.stringify(expected)
    ) {
      issue(
        errors,
        caseIndex,
        `${prefix}-note-assignments`,
        "Assign every MIDI note exactly once to a layer or to unassigned.",
      );
    }
  }

  response.singleChordAlternatives.forEach((alternative, alternativeIndex) => {
    if (typeof alternative !== "string" || alternative.trim() === "") {
      issue(
        errors,
        caseIndex,
        `${prefix}-alternative-${alternativeIndex}`,
        `Alternative ${alternativeIndex + 1} cannot be blank.`,
      );
    }
  });

  for (const input of INPUT_CONDITIONS) {
    const judgment = response.inputEligibility[input];
    if (!ELIGIBILITY_STATUSES.includes(judgment?.status)) {
      issue(
        errors,
        caseIndex,
        `${prefix}-${input}-status`,
        `Choose an eligibility status for ${input}.`,
      );
    }
    if (typeof judgment?.reason !== "string" || judgment.reason.trim() === "") {
      issue(
        errors,
        caseIndex,
        `${prefix}-${input}-reason`,
        `Explain the eligibility judgment for ${input}.`,
      );
    }
  }
}

export function validateInstrumentState(template, state) {
  assertTemplate(template);
  const errors = [];
  if (!ANNOTATOR_ID.test(state.annotatorId)) {
    issue(
      errors,
      null,
      "annotator-id",
      "Use an opaque 3-64 character ID containing only letters, numbers, dots, underscores, or hyphens.",
    );
  }
  if (!validIsoDate(state.completedOn)) {
    issue(errors, null, "completed-on", "Enter a valid completion date.");
  }
  if (
    !Array.isArray(state.responses) ||
    state.responses.length !== template.cases.length
  ) {
    issue(
      errors,
      null,
      "review-form",
      "The saved draft does not match this packet.",
    );
    return errors;
  }

  state.responses.forEach((response, caseIndex) => {
    const canonical = canonicalResponse(
      response,
      template.cases[caseIndex].evidence,
    );
    validateCase(
      canonical,
      template.cases[caseIndex].evidence,
      caseIndex,
      errors,
    );
  });
  return errors;
}

export function caseIsComplete(template, state, caseIndex) {
  if (!state.responses[caseIndex]) {
    return false;
  }
  const errors = [];
  const response = canonicalResponse(
    state.responses[caseIndex],
    template.cases[caseIndex].evidence,
  );
  validateCase(response, template.cases[caseIndex].evidence, caseIndex, errors);
  return errors.length === 0;
}

export class InstrumentValidationError extends Error {
  constructor(errors) {
    super("The review contains incomplete or invalid responses.");
    this.name = "InstrumentValidationError";
    this.errors = errors;
  }
}

export function buildCompletedPacket(template, state) {
  const errors = validateInstrumentState(template, state);
  if (errors.length > 0) {
    throw new InstrumentValidationError(errors);
  }

  const completed = clone(template);
  completed.status = "complete";
  completed.reviewMetadata = {
    annotatorId: state.annotatorId,
    completedOn: state.completedOn,
  };
  completed.cases.forEach((reviewCase, caseIndex) => {
    reviewCase.response = canonicalResponse(
      state.responses[caseIndex],
      reviewCase.evidence,
    );
  });
  return completed;
}
