# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog][1], and this package adheres to
[Semantic Versioning][2].

[1]: https://keepachangelog.com/en/1.1.0/
[2]: https://semver.org/

## [Unreleased]

### Added

- Initial extraction of the WhatChord analysis engine into a standalone pure
  Dart package: chord identification (`ChordAnalyzer`), ranked candidates with
  explanation traces, note spelling, scale harmonization and degree
  classification, chord construction from a selected spec, and formatters for
  chord symbols, spoken names, long-form names, and Harte notation.
- Temporal module: `ChordEvent` (a committed chord from live play) and
  `ChordEventSegmenter`, the capture model that feeds key detection and future
  temporal-context analysis.
- Polychord analysis primitives: symmetric register candidate generation,
  conservative selector diagnostics, secondary-annotation stability, and
  threshold-free per-note onset evidence.
- Pure-Dart temporal polychord tracking for normalized note and sustain-pedal
  events, including carried-in notes, reattacks, and exact onset provenance.
- Threshold-free release and sustain-pedal provenance for polychord candidates,
  including current-state origins and prior sustained-instance releases.
- Frame-transition evidence and the separately named rigid-layer motion-support
  interpretation, with no inferred voice assignments or endpoint policy.
- The separately named conservative onset-cohort interpretation, kept distinct
  from selector licensing and display policy.
- Exact reset-scoped candidate-to-sounding-instance binding and revalidation,
  including explicit incomplete carried-in history.
