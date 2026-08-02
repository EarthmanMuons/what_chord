export const PRESENTATION_SCHEMA = "polychord-review-presentation/1";

export const PITCH_CLASS_LABELS = [
  "C",
  "C♯/D♭",
  "D",
  "D♯/E♭",
  "E",
  "F",
  "F♯/G♭",
  "G",
  "G♯/A♭",
  "A",
  "A♯/B♭",
  "B",
];

export const ORIENTATION_EXAMPLES = [
  {
    id: "orientation-separated-triads",
    title: "Two chordal units are the intended construction",
    description:
      "A lower E-flat-major triad and an upper A-major triad are introduced as separate chordal units and sound together.",
    midiNotes: [39, 43, 46, 57, 61, 64],
    answer: "Polychord reading expected",
    explanation:
      "The construction explicitly combines two conventional triads. One simultaneous sonority contains both complete units.",
  },
  {
    id: "orientation-integrated-sixth",
    title: "One familiar chord has duplicated notes",
    description:
      "The notes are voiced and attacked together as one A6 chord. A and C-sharp are duplicated across registers.",
    midiNotes: [45, 49, 52, 54, 57, 61],
    answer: "A polychord reading would be misleading",
    explanation:
      "Register alone can suggest smaller note groups, but the complete collection has a direct, ordinary A6 reading.",
  },
  {
    id: "orientation-upper-structure",
    title: "A decomposition is useful but not the primary name",
    description:
      "A D-major upper-structure triad is voiced over a C-major-seventh shell in a jazz-harmony context.",
    midiNotes: [36, 52, 59, 62, 66, 69],
    answer: "Possible decomposition, but a single-chord reading is preferable",
    explanation:
      "The two performance units are descriptively real, while Cmaj13(♯11) is the established integrated chord reading.",
  },
];

export const READINESS_QUESTIONS = [
  {
    id: "meaning",
    legend:
      "Does a polychord answer here claim that a listener hears two independent keys?",
    options: [
      { value: "no", label: "No. It is a constructional or notational claim." },
      { value: "yes", label: "Yes. Two perceived keys are required." },
    ],
    correct: "no",
  },
  {
    id: "uncertainty",
    legend:
      "What should you do when the evidence or guide does not support a responsible construction choice?",
    options: [
      {
        value: "abstain",
        label: "Choose cannot determine and explain what is missing.",
      },
      {
        value: "force",
        label: "Choose the nearest of the other three labels.",
      },
    ],
    correct: "abstain",
  },
  {
    id: "unit",
    legend:
      "May notes from different moments be combined and called one simultaneous sonority?",
    options: [
      { value: "no", label: "No. Use a short passage unfolding over time." },
      { value: "yes", label: "Yes. Collect every note in the passage." },
    ],
    correct: "no",
  },
];

export function pitchClassLabel(pitchClass) {
  if (!Number.isInteger(pitchClass) || pitchClass < 0 || pitchClass > 11) {
    throw new RangeError("Pitch class must be an integer from 0 through 11.");
  }
  return PITCH_CLASS_LABELS[pitchClass];
}

export function midiNoteLabel(midiNote) {
  if (!Number.isInteger(midiNote) || midiNote < 0 || midiNote > 127) {
    throw new RangeError("MIDI note must be an integer from 0 through 127.");
  }
  const octave = Math.floor(midiNote / 12) - 1;
  return pitchClassLabel(midiNote % 12)
    .split("/")
    .map((name) => `${name}${octave}`)
    .join("/");
}

export function formatNoteList(midiNotes) {
  return midiNotes.map(midiNoteLabel).join(", ");
}

export function formatOnsetTime(milliseconds) {
  if (milliseconds === 0) return "At the start";
  const seconds = milliseconds / 1000;
  return `${Number.isInteger(seconds) ? seconds : seconds.toFixed(1)} seconds later`;
}

export function assertPresentationManifest(manifest) {
  if (manifest?.schema !== PRESENTATION_SCHEMA) {
    throw new Error("The score-excerpt manifest uses an unexpected schema.");
  }
  if (
    !manifest.scoreExcerpts ||
    typeof manifest.scoreExcerpts !== "object" ||
    Array.isArray(manifest.scoreExcerpts)
  ) {
    throw new Error("The score-excerpt manifest has no source mapping.");
  }
  for (const [sourceIdentifier, excerpt] of Object.entries(
    manifest.scoreExcerpts,
  )) {
    if (
      excerpt?.source?.sourceIdentifier !== sourceIdentifier ||
      typeof excerpt?.source?.sourceUrl !== "string" ||
      typeof excerpt?.source?.scoreLocation !== "string"
    ) {
      throw new Error("A score-excerpt source identifier is inconsistent.");
    }
    if (
      typeof excerpt?.source?.pdfSha256 !== "string" ||
      typeof excerpt?.asset?.file !== "string" ||
      typeof excerpt?.asset?.sha256 !== "string" ||
      !Number.isInteger(excerpt?.asset?.width) ||
      !Number.isInteger(excerpt?.asset?.height) ||
      typeof excerpt?.asset?.alt !== "string"
    ) {
      throw new Error(
        `The score excerpt for ${sourceIdentifier} is incomplete.`,
      );
    }
  }
}

export function scoreExcerptForEvidence(manifest, evidence) {
  assertPresentationManifest(manifest);
  if (evidence.kind !== "score-source") return null;
  const excerpt = manifest.scoreExcerpts[evidence.source.sourceIdentifier];
  if (!excerpt) {
    throw new Error(
      `No score excerpt is pinned for ${evidence.source.sourceIdentifier}.`,
    );
  }
  if (excerpt.source.pdfSha256 !== evidence.source.sha256) {
    throw new Error("The score excerpt and review packet cite different PDFs.");
  }
  if (excerpt.source.sourceUrl !== evidence.source.sourceUrl) {
    throw new Error(
      "The score excerpt and review packet cite different sources.",
    );
  }
  if (excerpt.source.scoreLocation !== evidence.source.scoreLocation) {
    throw new Error(
      "The score excerpt and review packet cite different score locations.",
    );
  }
  return excerpt;
}

export function readinessIsComplete(answers) {
  return READINESS_QUESTIONS.every(
    (question) => answers[question.id] === question.correct,
  );
}
