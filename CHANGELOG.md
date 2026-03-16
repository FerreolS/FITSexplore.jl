# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-03-16

### Features
- Command-line FITS inspection tool (`fitsexplore`) supporting single-file and multi-file workflows.
- Recursive directory traversal (`-r`, `--recursive`) with online processing of discovered files.
- File listing mode (`-l`, `--list`) to enumerate FITS candidates from paths/directories.
- Header keyword query mode (`-k`, `--keyword`) for focused metadata extraction.
- Header-based filtering mode (`-f`, `--filter`) for selecting files by keyword/value criteria.
- Statistical summary mode (`-s`, `--stats`) for dataset-level overview operations.
- Plot-oriented output mode (`-p`, `--plot`) for quick terminal visualization workflows.

### Package API
- Public package entrypoint `fitsexplore` for programmatic use.
- Canonical in-place filtering helper `filter_keyword!` for online filtering of file collections.

### Behavior
- Quiet default behavior for malformed FITS files outside explicit list mode.
- Explicit malformed FITS warning emission in list mode (`-l`, `--list`).
- Robust option parsing for keyword/filter arguments and CLI edge cases.

### Engineering
- Internal split between parsing (`src/parse.jl`) and rendering/output (`src/print.jl`) modules.
- Precompile workload coverage for recursive execution paths.
- Test suite coverage for recursive mode, parser edge cases, and malformed-warning policy.
