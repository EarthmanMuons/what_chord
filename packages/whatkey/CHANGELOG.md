# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog][1], and this package adheres to
[Semantic Versioning][2].

[1]: https://keepachangelog.com/en/1.1.0/
[2]: https://semver.org/

## [Unreleased]

### Added

- Initial extraction of the WhatKey detection engine into a standalone pure Dart
  package: the shipped HMM detector and its research alternatives (profile
  correlation, weighted evidence, progression, BOCPD, hybrid), claim hysteresis,
  display calibration, key profiles and key-space utilities, and the
  `KeyBehavior` timescale presets.

### Changed

- Align the unnamed hybrid and profile detector constructors with the shipped
  HMM scoring path, and expose their earlier standalone configurations through
  explicit `researchBaseline` constructors.
- Skip construction and evaluation of research-only functional and progression
  scorers when their blend weights are disabled.
