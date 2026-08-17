# mi-lib metapackage

A metapackage for the [mi-lib](https://github.com/mi-lib) libraries:
it manages a configurable set of upstream libraries (originals or your
forks) together with one custom library that depends on them, builds
and installs everything in dependency order, pins and restores exact
versions, generates a compilation database for clangd, and keeps up
with upstream updates through CI.

Everything is driven by a layered configuration: `config.default`
(tracked) holds the documented defaults, an optional gitignored
`config.local` overlays only the values you change, and environment
variables override both. The library clones live inside this directory
but are ignored by git.

## Scripts at a glance

All scripts read the same layered configuration through
`load_config.sh` (not a user command). `fork.sh`, `sync_upstream.sh`,
and the freeze/thaw pair accept `--dry-run`; `clone.sh` is idempotent
and skips existing clones:

| script | what it does | when to run |
|---|---|---|
| `install_prereq.sh` | installs the required system packages (`--check` to verify only) | once per machine |
| `fork.sh` | forks the upstream libraries into your account | once per account (no-op in forkless mode) |
| `clone.sh` | clones the configured libraries, adds `upstream` remotes | once per machine, or after adding a library |
| `sync_upstream.sh` | fast-forwards each library's `main` to upstream (and pushes the forks) | when `upstream-check` reports updates |
| `build_compile_commands.sh` | clean rebuild, regenerates the compilation database and `.clangd`, freezes versions | after any library changes |
| `freeze_versions.sh` | records each library's current commit into the lock file | after a combination proves good (automatic at the end of a successful `build_compile_commands.sh`) |
| `thaw_versions.sh` | checks the recorded commits out again | to roll back or reproduce the locked state |
| `gen_envrc.sh` | writes the direnv `.envrc` for the install prefix | project-local installs (Pattern 3) |

In short: `clone.sh` makes the working copies exist,
`sync_upstream.sh` moves them forward to the newest upstream state,
and `freeze_versions.sh`/`thaw_versions.sh` pin and restore a known
good combination.

## Pattern 1: system install with the default configuration

Installs all the upstream libraries and [pedi2](https://github.com/hrshtst/pedi2)
to `~/usr`:

```console
$ ./install_prereq.sh   # install required packages (sudo; --check to verify only)
$ ./fork.sh             # fork the upstream libraries into your account (once)
$ ./clone.sh            # clone the libraries, add upstream remotes
$ make                  # build, install, and test everything
```

The `upstream-check` GitHub Actions workflow runs weekly: it compares
every fork with its upstream and, when updates exist, builds the
whole suite at the upstream state and runs the custom library's test
suite on a runner. The result is tracked in a single issue labeled
`upstream-check` (closed automatically once the forks are in sync).
To adopt updates locally:

```console
$ ./sync_upstream.sh --dry-run   # preview how far each library is behind
$ ./sync_upstream.sh             # fast-forward (and push the forks)
$ ./build_compile_commands.sh    # rebuild and re-freeze versions
```

## Pattern 2: custom configuration

Create `config.local` next to `config.default` and assign only what
differs. An assignment replaces the default value completely (there
is no appending), and CI never reads `config.local` — the workflow
always builds with the tracked defaults. The sub-patterns below go
from the simplest custom setup to a fully customized one.

### Pattern 2-a: original libraries only, without forks

Track a subset of the original mi-lib repositories directly over
HTTPS — no forks, no custom library, and, since the originals are
public, no GitHub account:

```sh
# config.local
UPSTREAM_LIBS="zeda zm dzco"    # must be dependency-closed
CUSTOM_LIB=""
OWNER="$UPSTREAM_OWNER"         # forkless mode: track the originals
GIT_PROTOCOL="https"
```

Then `./clone.sh && make` is everything: in forkless mode `fork.sh`
has nothing to do, `clone.sh` adds no upstream remotes, and
`sync_upstream.sh` fast-forwards from the originals without pushing
anywhere. Note that assigning `UPSTREAM_LIBS` replaces the default
list entirely — to manage the whole suite this way, list all ten
libraries — and the list must stay closed under the dependency graph
in the Makefile (e.g. dzco needs zeda and zm; roki-gl needs zeda zm
zeo roki zx11 liw).

### Pattern 2-b: your forks and your own custom library

The full workflow for developing your own library on top of the
suite. Start by forking this repository itself and cloning your fork:
the empty `OWNER`, `CUSTOM_LIB_OWNER`, and `GIT_PROTOCOL` defaults
are then derived from your clone's origin URL (your account, your
protocol). If you cloned someone else's metapackage instead, set
`OWNER` explicitly.

```sh
# config.local
UPSTREAM_LIBS="zeda zm"                   # what mylib needs
CUSTOM_LIB="mylib"                        # your repository's name
CUSTOM_LIB_DEPS="zeda zm"                 # its deps among UPSTREAM_LIBS
CUSTOM_TEST_CMD="make -C mylib/test test" # run by CI ("" to skip)
```

`./fork.sh` forks the configured upstream libraries into your account
(through the gh CLI, logging in if necessary), `./clone.sh` clones
your forks plus `mylib` and adds the original repositories as
`upstream` remotes to the forks, and `make` builds everything in
dependency order. The custom library is driven exactly like an
upstream one — `make`, `make install`, and `make example` run in its
directory with the configured `PREFIX` — so it must follow the mi-lib
makefile conventions (as [pedi2](https://github.com/hrshtst/pedi2)
does). Anything beyond that goes into `mk/mylib.mk`, which may append
phony targets to `CUSTOM_EXTRA_TARGETS` (joined into `all`) and
`CUSTOM_EXTRA_CLEAN` (joined into `clean`); see `mk/pedi2.mk`, which
adds pedi2's gtest suite and application directories this way. If the
custom library lives under a different account than the forks, set
`CUSTOM_LIB_OWNER`.

Since CI reads only `config.default`, commit your library set and
custom library there (in your fork of this repository) when the
weekly `upstream-check` workflow should build and test *your*
configuration; keep `config.local` for machine-local values.

### Pattern 2-c: pinning your own combination of versions

Extends Pattern 2-b for day-to-day development, where the forks and
the custom library move at their own pace and you want to snapshot
combinations that are known to work. The tracked `versions.lock`
records the default configuration of this repository; with a custom
library set, pin into a gitignored local lock instead:

```sh
# config.local (in addition to Pattern 2-b)
VERSIONS_LOCK="versions.local.lock"
```

`./freeze_versions.sh` snapshots the checked-out state of every
configured library into that file, and `./build_compile_commands.sh`
re-freezes after each successful rebuild, so the lock always points
at the last combination that built green. When an experiment goes
wrong — say `./sync_upstream.sh` pulls an upstream change that breaks
the custom library — `./thaw_versions.sh` restores the recorded
state, and a clean rebuild brings the installation back in line. To
share the pinned versions across machines instead, keep the default
`VERSIONS_LOCK="versions.lock"` and commit the lock in your fork of
this repository.

### Further configuration notes

- Environment variables override both config files for one-off runs,
  e.g. `PREFIX=/tmp/prefix ./build_compile_commands.sh` (precedence:
  environment > `config.local` > `config.default`).
- `GIT_PROTOCOL` accepts `ssh` or `https`; as with the owner
  variables, empty derives it from this repository's origin URL.
- `UPSTREAM_OWNER` names the organization hosting the original
  libraries and rarely needs changing.
- Values must not contain spaces — they travel through make and
  sub-make command lines unquoted.
- The installation-related variables — `PREFIX`, `APP_DIRS`,
  `COMPILE_DB`, and `ENVRC_DIR` (where `gen_envrc.sh` writes `.envrc`;
  empty = the directory containing `PREFIX`) — are the subject of
  Pattern 3.

## Pattern 3: project-local install with out-of-tree applications

Install into a project directory and develop applications outside
this repository:

```text
user_project/
├─ .clangd                <- generated by build_compile_commands.sh
├─ .envrc                 <- generated by gen_envrc.sh
├─ .local/                <- install prefix
│   ├─ bin/               <- <lib>-config scripts and tools
│   ├─ include/
│   │   ├─ zeda/
│   │   └─ zm/
│   └─ lib/
│       ├─ libzeda.so
│       ├─ libzeda_cpp.so
│       ├─ libzm.so
│       └─ libzm_cpp.so
├─ application/
│   └─ simulation1/       <- built via the installed <lib>-config
├─ third_party/mi-lib/    <- this repository
│                ├─ zeda/   <- library clones (gitignored)
│                ├─ zm/
│                └─ versions.local.lock
└─ compile_commands.json  <- includes the application sources
```

`config.local` for this layout:

```sh
UPSTREAM_LIBS="zeda zm"                                  # what you need
CUSTOM_LIB=""
PREFIX="/path/to/user_project/.local"
APP_DIRS="/path/to/user_project/application/simulation1"
COMPILE_DB="/path/to/user_project/compile_commands.json"
VERSIONS_LOCK="versions.local.lock"
```

Then `./clone.sh && make && ./build_compile_commands.sh` builds and
installs into `.local`, captures the application directories into the
database at the project root, and generates `.clangd` beside it so
clangd covers the application sources too. `./gen_envrc.sh` writes
the `.envrc` (run `direnv allow` afterwards). Application makefiles
compile via the installed `<lib>-config` scripts, which carry the
prefix automatically.

The three generated files at the project root — `.clangd`, `.envrc`,
and `compile_commands.json` — are machine-local; it is recommended to
list them (and `.local/`) in the project's own `.gitignore`.

Rules of the road: always build through this repository's Makefile
(it injects the configured `PREFIX` into the generated library
makefiles; a build started inside a library directory would fall back
to that library's own config), and a `PREFIX` change requires
`make clean` first — a stamp file enforces this, since the generated
`<lib>-config` tools bake the prefix in.

## Version pinning and the compilation database

`./freeze_versions.sh` records each library's commit, branch, and a
`dirty` marker into the lock file (`--dry-run` diffs against it);
`./thaw_versions.sh` checks the recorded commits out again, skipping
repositories with local changes. `./build_compile_commands.sh` cleans,
rebuilds everything under [bear](https://github.com/rizsotto/Bear),
captures the application directories, adds header entries with
[compdb](https://github.com/Sarcasm/compdb), and freezes the versions
— so the lock always reflects the last successful build. Restart
clangd in your editor after regenerating the database.

Troubleshooting: the generated library makefiles carry no header
dependencies, so after switching branches in a library, run a clean
rebuild before trusting build or test results.
