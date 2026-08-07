# mi-lib workspace

A meta repository for developing [pedi2](https://github.com/hrshtst/pedi2)
against forks of the [mi-lib](https://github.com/mi-lib) libraries
(zeda, zm, neuz, dzco, zeo, roki, liw, zx11, roki-gl, roki-fd).
The library clones live in this directory but are ignored by git;
`liblist` is the single manifest of their names, and `versions.lock`
records the exact commits the workspace was last built from.

## Setup

```console
$ ./install_prereq.sh   # install required packages (uses sudo; --check to only verify)
$ ./fork.sh             # fork the upstream libraries into your account (once)
$ ./clone.sh            # clone the forks and pedi2, add upstream remotes
$ make                  # build, install to ~/usr, and test everything
```

## Syncing with upstream

The `upstream-check` GitHub Actions workflow runs weekly (and via
manual dispatch). It compares every fork with its upstream and, when
updates exist, builds the whole suite at the upstream state and runs
pedi2's test suite on a runner. The result is tracked in a single
issue labeled `upstream-check`, whose verdict says whether the
updates are safe to pull; the issue is closed automatically once the
forks are back in sync.

To adopt upstream updates locally:

```console
$ ./sync_upstream.sh --dry-run   # preview how far each fork is behind
$ ./sync_upstream.sh             # fast-forward each fork's main and push it
```

The script only fast-forwards: a fork whose `main` carries local-only
commits is skipped and reported for manual handling. It also works
while another branch is checked out (the branch itself is left alone —
rebase it onto `main` yourself afterwards).

If the tracking issue reports a failed build, fix pedi2 on a branch
first, merge it, and sync afterwards; the next workflow run should
then be green.

After syncing, rebuild the workspace and the compilation database
(next section), and commit the updated `versions.lock`.

## Recreating compile_commands.json

`compile_commands.json` at the workspace root lets clangd navigate
across all libraries and pedi2. `.clangd` redirects header lookup to
the in-tree `include/` directories, so cross-library jumps land in
the sources rather than the installed copies under `~/usr/include`.

To recreate the database after syncing or larger changes:

```console
$ ./build_compile_commands.sh
```

This cleans everything, rebuilds the whole suite under
[bear](https://github.com/rizsotto/Bear) to capture the compile
commands, adds header entries with
[compdb](https://github.com/Sarcasm/compdb), and finally writes
`versions.lock` with each library's commit, branch, and a `dirty`
marker for uncommitted changes. Requirements: `bear` and `compdb` on
the PATH, and `~/usr/bin` in PATH with `~/usr/lib` in
`LD_LIBRARY_PATH` for the installed tools and tests ([direnv](https://direnv.net/)
is handy for setting these per directory).

Restart clangd in your editor after regenerating the database.
