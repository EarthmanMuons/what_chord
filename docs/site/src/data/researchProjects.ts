export interface ResearchProject {
  description: string;
  href: string;
  title: string;
}

export const whatKeyResearchProject = {
  description:
    "Naming the key while the music is still playing, from the chord recognizer’s output rather than a finished score, and staying quiet when the evidence is too thin to call.",
  href: "https://github.com/EarthmanMuons/whatchord/tree/main/research/whatkey",
  title: "WhatKey",
} satisfies ResearchProject;

export const researchProjects = [
  whatKeyResearchProject,
  {
    description:
      "How closely that detector should follow the brief key changes inside a piece, and what chasing them costs in the steadiness a glanceable indicator needs.",
    href: "https://github.com/EarthmanMuons/whatchord/tree/main/research/whatkey-local",
    title: "WhatKey Local",
  },
  {
    description:
      "Whether recently played chords, and the key they imply, sharpen live chord naming, tested against a strong baseline on two annotated classical corpora.",
    href: "https://github.com/EarthmanMuons/whatchord/tree/main/research/chord-context",
    title: "Chord Context",
  },
  {
    description:
      "A comping mode for the voicings a pianist plays over a bass player, where the root is deliberately absent and the engine previously had no name for the chord at all.",
    href: "https://github.com/EarthmanMuons/whatchord/tree/main/research/ensemble-mode",
    title: "Ensemble Mode",
  },
  {
    description:
      "Closing the naming errors that survive when the key is already correct, measured on a jazz comping benchmark built from the Weimar Jazz Database.",
    href: "https://github.com/EarthmanMuons/whatchord/tree/main/research/ensemble-tiebreak",
    title: "Ensemble Tiebreak",
  },
  {
    description:
      "Scoring chord identity on real recorded performances through the app’s own input path, where every earlier accuracy number had rested on clean synthesized voicings.",
    href: "https://github.com/EarthmanMuons/whatchord/tree/main/research/performed-input",
    title: "Performed Input",
  },
  {
    description:
      "What a chord name should pay for a tone it cannot explain, and what discount an honest incomplete reading deserves: one cost dial viewed from both sides.",
    href: "https://github.com/EarthmanMuons/whatchord/tree/main/research/tone-pricing",
    title: "Tone Pricing",
  },
] satisfies ResearchProject[];
