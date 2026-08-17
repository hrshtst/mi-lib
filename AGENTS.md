# AGENTS.md

This file provides guidance to AI coding agents when working with code
in this repository.

## What this is

A metapackage that builds and installs a configurable set of mi-lib
robotics libraries plus one custom library (default: pedi2). The
library clones live inside this directory but are gitignored — each is
an independent git repository (not a submodule); operate on them with
`git -C <lib>`. Configuration is layered (environment >
`config.local`, gitignored > `config.default`, tracked), all loaded
through `load_config.sh`. See README.md for usage patterns.

## Commands

- `make` — build, install, and test everything to the configured
  PREFIX; `make SKIP_CHECKS=1` skips the libraries' test/example
  targets (what CI uses).
- `./build_compile_commands.sh` — clean rebuild under bear,
  regenerates `compile_commands.json` and `.clangd`, then freezes the
  version lock.
- `./freeze_versions.sh` / `./thaw_versions.sh` pin and restore
  library versions; `./sync_upstream.sh` fast-forwards to upstream.
- Changing PREFIX requires `make clean` first (a stamp file enforces
  this).

## Shell scripts

- Every shell script must pass `shellcheck -x` (and `bash -n`) before
  it is committed.
- `load_config.sh` is sourced into `set -euo pipefail` scripts: use
  only `if` forms (no `[ ... ] && ...` line-enders) and tolerate unset
  variables.
- Config values must not contain spaces (they travel through make
  command lines unquoted).
- CI must never read `config.local`: workflow steps source
  `./config.default` directly — preserve that when editing
  `.github/workflows/upstream-check.yml`.

## Gotchas

- The generated library makefiles have no header dependencies: after
  switching branches or syncing in any library, run a clean rebuild
  before trusting build or test results.
- The interactive shell is zsh: after a pipeline, `$?` is the last
  command's status (`cmd | tail` hides failures), and unquoted `$VAR`
  does not word-split. Run the repo's scripts with bash and check exit
  codes without pipes.
- `versions.lock` records the last green build and must stay
  reproducible from its commit IDs alone: `freeze_versions.sh` refuses
  dirty libraries (untracked files are never captured), and
  `build_compile_commands.sh` checks cleanliness before rebuilding,
  freezing on success.

## Conventions

- Commit messages in this repository: `type: Concise imperative
  subject` (docs:/chore:/fix:/feat:), then one concise paragraph
  after a blank line.
- Commits made inside the library clones that may become upstream
  PRs follow the upstream (zeda) convention instead: a past-tense
  descriptive sentence, e.g. "Added method assignArray of
  zIndexStruct for C++.", with any detail in a concise paragraph
  after a blank line.
- Make commits in review-sized pieces; never commit or push without an
  explicit instruction.
- README prose is wrapped at roughly 70 columns.
- Text destined for upstream (mi-lib org) PRs or issues describes
  problems generically, without tool-specific narratives (in
  particular, do not mention bear).
