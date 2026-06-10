# Dotfiles Repository Review

**Date:** 2026-06-10
**Method:** Full read of all 56 tracked files (~13.6k lines), `make doctor`, full Docker test suite (`make test`: 396 pass, 27 skip), plus empirical repros for suspected bugs. Findings marked **[verified]** were reproduced in a terminal during this review; everything else is from code reading.

> **Resolution (2026-06-10, branch `tv/review-fixes`):** every finding below
> was addressed the same day — see the branch's commit history for the
> per-area fixes. Item 12 was retracted (wrong about nvim 0.12). The suite
> grew from 396 tests (27 skipped) to 430+ with only the two fzf-interactive
> skips remaining. Inline `[bracketed]` review comments are answered in place.

---

## Overall assessment

This is a far stronger repo than the typical dotfiles project. It has a real test suite running in Docker isolation, CI, git hooks, a static validator (`doctor`), dry-run modes, automatic backups with restore, an adoption workflow, and consistently excellent `-h` help text. The bash-3.2 discipline (parallel arrays, no associative arrays) is applied consistently, and the design has a coherent extension-point philosophy (`~/.zshrc.local`, `~/.gitconfig.local`, `nvim/local.vim`).

The weaknesses cluster in three places:

1. **Error-handling blind spots** — several scripts use `set -e` in ways that silently defeat their own failure-handling code (install-tools' summary, test-runner's failure banner), and a few "safety" features (`--dry-run`, `restore`) are only partially wired up.
2. **The gap between what's tested and what's risky** — the symlink manager is tested to death (and it shows: it's solid), while `install-tools.sh`, `restore`, and the zsh wrapper functions are effectively untested, and that's exactly where the bugs are.
3. **Documentation/coverage drift** — CLAUDE.md's git aliases are stale, doctor's hardcoded syntax-check list omits `envsync`, the Ubuntu test image is dead infrastructure, and 27 test skips mean zsh/tmux/nvim configs are never validated in CI.

---

## Confirmed bugs (reproduced during review)

### 1. `config` without a trailing newline silently drops the last entry — [verified]

`validate_config` reads with `|| [ -n "$line" ]` (`src/symlink-manager.sh:110`), so it sees a final line that lacks a trailing newline. The install/uninstall/status loops do not (`src/symlink-manager.sh:160,216,245`). Result: validation (and `doctor`, which also handles the no-newline case) passes, then `make link` silently skips the last entry. Repro:

```
$ printf 'file-a\nfile-b' > config
validate-style loop: sees file-a, file-b
install-style loop:  sees file-a only
```

**Fix:** add `|| [ -n "$filepath" ]` to all four read loops (or normalize the file first). Cheap test to add alongside.

### 2. `e -m` mis-handles filenames containing " D" or " M" — [verified]

`src/dotfiles/.local/bin/e:331-334` parses `git status --porcelain` with unanchored alternations: `grep '^ M\| M\|^M'` and `grep -v '^D\| D'`. The unanchored ` D` / ` M` match anywhere in the line — including the _filename_. Repro: a modified file named `bar D.txt` is silently excluded from `e -m`; an untracked `foo M.txt` would be wrongly included. Additional latent issues in the same code path: rename entries (`R  old -> new`) come out as the literal string `old -> new` after `cut -c4-`, and porcelain C-quotes filenames containing special characters.

**Fix:** drop porcelain parsing; use `git diff --name-only` + `git diff --cached --name-only` (and `git ls-files --others --exclude-standard` for `-u`), ideally with `-z`.

### 3. `git-prune-branches` loses branches checked out in other worktrees — [verified]

`git branch -vv` prefixes worktree-checked-out branches with `+`, so `awk '{print $1}'` (`src/dotfiles/.local/bin/git-prune-branches:137`) yields `+` instead of the branch name. Repro:

```
+ feature 1c849d9 (/private/tmp/wt-test-branch) init
* main    1c849d9 init
awk '{print $1}' →  "+"  "*"
```

The real branch name is lost from gone-detection, and `should_skip` doesn't filter `+`, so a literal branch named `+` can be added to the prune list (deletion then fails with a confusing message). Given this is a worktree-heavy workflow (you built `git-prune-worktrees` and `gw`), this path is live. The `[merged]` detection has a related wart: `echo "$branch" | xargs` (line 130) is used to trim whitespace, but xargs interprets quotes — a branch name containing `'` makes it error.

**Fix:** use `git for-each-ref refs/heads --format='%(refname:short) %(upstream:track)'` instead of parsing human-oriented `git branch` output.

### 4. The editor spawned by `e` gets a non-tty stdin — [verified]

`e` builds args and pipes them to `xargs -0 $editor` (`src/dotfiles/.local/bin/e:537`). Verified: the xargs child's stdin is the exhausted pipe, not the terminal. nvim recovers (it reopens the controlling tty), which is why daily use works — but the help text advertises vim/nano/micro support (`e:58`), and those misbehave with a non-tty stdin (the classic xargs-vim problem).

**Fix:** read the null-separated args into a bash array and `exec "$editor" "${args[@]}"` (keeps stdin as-is), or use `xargs -o` (BSD) / `--open-tty` (GNU ≥4.8) — the array approach is portable and removes the subshell.

---

## High-confidence bugs (from code reading)

### 5. `install-tools.sh`: `set -e` defeats the entire failure-handling design — **highest-impact bug in the repo**

Two compounding problems (`src/install-tools.sh`):

- `install_tool` returns 1 on failure (line 169) and is called bare at top level (`install_tool nvim neovim`, line 317). Under `set -e` (line 5), the **first core-tool failure aborts the script immediately** — no summary, no "please install manually" guidance. The entire `failed_tools` summary block (lines 453–460) is unreachable for core tools.
- The prompted optional installer (`install_optional`, used for ollama/dotnet/php) _does_ return 0 on failure but appends to `failed_tools` (lines 280–282). So the only way the "Critical tools failed" branch can trigger is via **optional** tools — and it then `exit 1`s, which **aborts `make setup` before any symlinks are created**. On stock Ubuntu, answering "y" to dotnet (not in default repos) kills the whole setup.

**Fix:** call core installs as `install_tool nvim neovim || true` (the function already records failures — once `set -e` stops eating them), and give `install_optional` its own `failed_optional_tools` bucket. Also worth a `sudo apt update` before the first apt install on Linux, and collapsing the three nearly identical 50-line installer functions into one helper with a `criticality` parameter (~110 lines saved, one place to fix).

### 6. `--dry-run` is silently ignored for `uninstall` and `restore`

The flag parser accepts `-n` with any mode, and the script header documents it as global (`src/symlink-manager.sh:5`), but only `install_dotfiles` checks `DRY_RUN`. `symlink-manager.sh --dry-run uninstall` **actually removes your symlinks** while the user believes they're previewing. Not reachable via make targets, but it's the script's own advertised interface. **Fix:** honor it in uninstall (trivial), and either implement or reject it for restore. A test for `-n uninstall` would have caught this.

### 7. `restore` writes through your symlinks, clobbering repo sources

`restore_from_backup` does `cp -R "$backup_dir"/. "$DESTINATIONDIR/"` (`src/symlink-manager.sh:313`) while the dotfile symlinks are still in place. Copying a file onto an existing symlink writes _through_ it — so restoring `.zshrc` overwrites `src/dotfiles/.zshrc` in the repo, silently destroying uncommitted changes. The script knows about this: it prints "You may want to run 'make teardown' first" — **after the copy has already happened** (line 315).

Also, the choice validation (lines 297–305) doesn't catch non-numeric input: both guarded comparisons fail closed, execution proceeds to `${backups[$((choice-1))]}`, and arithmetic on garbage yields index `-1` — on bash ≥ 4.3 that's the **last (oldest) backup**, restored without further confirmation.

**Fix:** unlink first (or refuse while links exist), validate `choice` with a regex, and add a non-interactive test (`echo 1 | symlink-manager restore`) — current tests only pipe `echo 0` (cancel).

### 8. `proj()` zsh wrapper breaks any session name containing "-d"

`src/dotfiles/.zsh/functions.zsh:41-54` special-cases a "detach mode (-d)" that the `proj` script no longer has (its flags are `-c`/`-k`/`-h`). The check `[[ "$*" == *"-d"* ]]` substring-matches session names: `proj my-dev` runs the script inside `$( )`, so `tmux attach` gets a piped stdout and fails ("not a terminal"). The whole branch is vestigial. **Fix:** delete the wrapper (call the script directly) or reduce it to plain pass-through. Notably, `tmp()` and `proj()` wrappers have no tests, while `gw()` does.

### 9. Arrow-key history search breaks without antigen/oh-my-zsh

`.zshrc:55-58` binds `up-line-or-beginning-search`, a widget that only exists because oh-my-zsh autoloads it. In the advertised graceful-degradation scenario (antigen missing — the exact case the `typeset -f antigen` guard at `.zshrc:33` is designed for), pressing ↑ yields "No such widget". **Fix:** three lines — `autoload -U up-line-or-beginning-search down-line-or-beginning-search; zle -N ...` before the bindkeys. Related gap: without OMZ, no HISTSIZE/SAVEHIST/HISTFILE is configured at all, so history barely persists.

### 10. The antigen install check can never succeed

`install_optional_tool antigen` (`src/install-tools.sh:361`) tests `command -v antigen`, but antigen is a zsh _function_ defined by sourcing `antigen.zsh` — in the installer's bash context it never exists as a command. Consequences: `brew install antigen` re-runs on every `make install`/`make setup` and the summary reports "Newly installed: antigen" every time (idempotency lie); on apt the package is named `zsh-antigen`, so Linux always reports "not available in repos". **Fix:** check for the file the zshrc actually sources (`$HOMEBREW_PREFIX/share/antigen/antigen.zsh` or `~/.zsh/antigen.zsh`), and map the apt package name.

### 11. nvm alias-chain resolution can hang shell startup

The lazy-load block resolves alias chains with `while [[ -f "$default_alias" ]]` (`.zshrc:124-127`). A cyclic alias (e.g. `default → default`, one stray `nvm alias` away) is an **infinite loop during every shell startup** — the worst possible failure location. **Fix:** cap iterations (e.g. `for _ in 1 2 3 4 5`).

### 12. ~~Suspected: lualine LSP shift-click runs a nonexistent command~~ — RETRACTED

**You were right.** Verified: `nvim --clean --headless "+lsp restart" +q` on nvim 0.12.2 errors with "No clients attached to current buffer" (a runtime condition), not E492 — the `:lsp` command exists in 0.12. My claim was based on 0.11 behavior. No code change made.

---

## Design concerns (working today, but load-bearing assumptions)

**`git-prune-worktrees` destroys ignored files in "synced" worktrees.** `git status --porcelain` doesn't show ignored files, so a worktree can be classified `[synced]` while containing `.env` files, `node_modules`, build caches — and `git worktree remove --force` (lines 261, 299) deletes them without a word. There's some irony in the same repo shipping `envsync` because `.env` files matter. Consider checking `git -C "$path" status --porcelain --ignored=matching` and demoting to a `[synced, has-ignored]` state, or at least documenting the behavior in `-h`.

**Backups follow symlinks (`cp -RL`, `src/symlink-manager.sh:143`).** Two effects: (a) a _dangling_ symlink nested inside a backed-up directory makes `cp -RL` fail, and under `set -e` the install dies mid-run with a half-linked HOME; (b) the backup is not a faithful copy (symlink structure is lost), so restore materializes copies where links used to be. `cp -PR` preserves structure and can't fail on dangling links. tests/README records `-RL` as a deliberate fix for path preservation — worth revisiting whether `-PR` + `mkdir -p` achieves the same without the failure mode.

**Parent-conflict handling only goes one level deep** (`src/symlink-manager.sh:191-199`). If `~/.config` is a regular _file_ and config wants `.config/bat/config`, the immediate parent (`~/.config/bat`) doesn't exist, the file-parent backup never triggers, and `mkdir -p` fails mid-install ("Not a directory").

**Status/uninstall output is ambiguous, and summaries overstate.** Three distinct conditions (foreign symlink / regular file / missing) all print an identical bare `⚠` with no explanation (`src/symlink-manager.sh:228-233, 258-262`), and uninstall always ends with "All dotfiles unlinked" even when items were skipped. A short reason suffix (`(not a symlink)`, `(points elsewhere)`) would make `make status` actually diagnostic.

**Filenames are interpolated into printf _format strings_** (`printf "  ✓ ${filepath}\n"`, throughout symlink-manager and check-tools). A `%` in a path garbles output (no injection risk, just wrong). `doctor.sh` does it right (`%s`); the others should match. Similarly, unquoted prefix strips like `${path#$TARGET_DIR/}` appear in several scripts and misbehave when the prefix contains glob metacharacters (`[`, `*`) — `${path#"$TARGET_DIR"/}` is the safe spelling.

**`.gitconfig` aliases hardcode `main`** (`smp`/`fmom`/`from`, `.gitconfig:18-20`) — all three fail in master-default repos, _including this dotfiles repo_. You already wrote default-branch detection three times (`e`, both prune scripts); the aliases can use the same trick: `!git switch $(git symbolic-ref --short refs/remotes/origin/HEAD | cut -d/ -f2-)`. Also: no `user.email` and no guard — on a machine without `~/.gitconfig.local`, commits pick up a system-guessed identity. `[user] useConfigOnly = true` makes git fail loudly instead.

**nvim config requires 0.11+ but the installer doesn't.** `vim.lsp.config` (plugins/init.lua:173+), `client:notify` method-call syntax (line 257), and treesitter's `main` branch (line 349) all need nvim 0.11. `install-tools.sh` installs whatever the distro has — Ubuntu 22.04 apt ships neovim 0.6, which will error on every one of these. Dockerfile.dev already works around this with a PPA (tests/docker/Dockerfile.dev:33), which proves the gap is known. Document the minimum version, and consider having install-tools warn or install from GitHub releases on Linux. Relatedly, **`lazy-lock.json` isn't tracked**, so a fresh machine gets unpinned latest-of-everything — tracking the lockfile is standard lazy.nvim practice and makes `make setup` reproducible.

**init.vim autocmds have no augroup** while `<leader>sv` re-sources `$MYVIMRC` (init.vim:194) — every re-source duplicates the `BufEnter`/`BufReadPost`/`BufLeave` autocmds (the BufEnter auto-cd at lines 4-9 starts running twice, etc.). Wrap them in `augroup vimrc | au! ...`.

**tmux clipboard is half cross-platform.** The middle-click paste handles both (`xclip || pbpaste`, .tmux.conf:70), and tmux-yank fixes `y` cross-platform at plugin load, but the explicit `Enter → pbcopy` binding (line 166) remains macOS-only on Linux. Minor since the platform claim is soft; one `command -v`-style conditional or deleting the redundant bindings (tmux-yank covers them) resolves it. Also `bind n` hardcodes `~/notes/scratch.md` (line 189) — fine if `~/notes` exists everywhere you care about.

**`e` performance and composition edges:** the `-g` content filter spawns one `git grep` _per file_ (e:455-460) — a single `git grep -ql pattern -- <files>` pass does it in one process. `-r` combined with `-u` silently ignores `-u`; `e - file.txt` silently ignores `file.txt` (e:296-298). Patterns passed to plain `grep` without `-e`/`--` (name/positional filters, e:435,443) error on patterns starting with `-`.

---

## Test suite

**What's genuinely strong:** per-test `mktemp` isolation with HOME override (consistently applied); the symlink-manager suite covers spaces in filenames, trailing slashes, comments, unsafe-path rejection, backup integrity, idempotency, and permission preservation; the `e` suite (65 tests) uses a mock `$EDITOR` that records its argv — the right technique; conflict/backup integration tests verify content round-trips, not just exit codes. The suite has clearly paid for itself (tests/README documents bugs it caught).

**Where it's hollow:**

- `test-install-tools.bats` is mostly theater — it tests that bash arrays work, that mock scripts run, and that `command -v` behaves (`tests/unit/test-install-tools.bats:89-218`); the script's actual logic is never executed. Six tests are skipped with "needs refactoring/real package manager". A single test that runs `main` with a mocked failing `brew` on PATH would have caught bug #5 immediately. The skip notes themselves point the way: extract pure functions (OS detect, install-one-tool) so they're testable.
- The `restore` copy path, `--dry-run uninstall`, and config-without-trailing-newline are all untested — and all three hide real bugs (#1, #6, #7).
- The `tmp()`/`proj()` zsh wrappers in functions.zsh are untested (bug #8 lives there); `gw()` shows the pattern for testing them.

**Infrastructure:**

- **BATS is downloaded from GitHub at container runtime on every `make test`** (tests/test-runner.sh:51-66) — a network dependency the tests/README even has a troubleshooting entry for. Baking it into the Dockerfile (one cached layer) makes every run faster and offline-capable.
- **27 skips mean zsh, tmux, and nvim configs are never validated in CI.** Alpine lacks zsh/tmux/nvim, so all of `test-configs.bats`'s runtime checks skip — a zsh syntax error in `.zshrc` would merge green (pre-commit catches it locally, but only on machines with hooks installed). `apk add zsh tmux neovim` in Dockerfile.alpine converts ~19 skips into real coverage for pennies of image size.
- **Dockerfile.ubuntu is dead infrastructure** — nothing invokes it (`run_docker_tests` takes a dockerfile param no caller passes; no make target). Either wire it up (`make test-ubuntu`, or a CI matrix) or delete it. *[delete] → done; Dockerfile.dev (Ubuntu) remains for `make dev-shell`.*
- **The failure banner in test-runner.sh is unreachable**: under `set -e`, a failing `bats` exits the script before `exit_code` is captured (tests/test-runner.sh:179-190), so the red "Some tests failed" box can never print. Failures still propagate (CI works); the cosmetics are dead code. Capture with `bats ... || exit_code=$?` instead.
- **CI only runs on push to master** (.github/workflows/test.yml:3-5) — no `pull_request` trigger, so a PR-based workflow gets zero CI until after merge. Also worth adding: a `make doctor` step (free, catches config/source drift), and shellcheck (none of the findings in this review would all surface, but SC2086-class issues would). *[add if cheap] → it was one line; added `pull_request` plus `doctor` and `shellcheck` jobs and a `make shellcheck` target.*

---

## Documentation

- **README.md** — the strongest doc; personable, accurate, and the forking/adding-dotfiles sections are genuinely usable. One stale claim: `make install` "prompts to also install optional tools" — only the three language tools prompt; the modern CLI tools install unconditionally.
- **CLAUDE.md drift** (notable given its own first rule is "ALWAYS update documentation"): *[dedupe?] → yes, deduped: per-script flag documentation and alias/function inventories were the drift generators; CLAUDE.md now keeps operational guidance and points at each script's `-h` and the README for details.*
  - Git aliases section lists `ci`, `br`, `co`, `lg` — none exist; the real set is `a/c/cm/s/f/p/l/ll/cfg/amend/smp/fmom/from`.
  - Custom-scripts section omits `sysinfo` (README has it).
  - Test architecture lists 3 unit test files; there are 11.
- **doctor.sh's hardcoded syntax-check list omits `envsync`** (src/doctor.sh:198) — the newest script is the one not checked (`bash -n` list predates it). Glob `.local/bin/*` and sniff shebangs instead of enumerating; that makes the next script automatic. (Same shebang-sniffing fix applies to `.githooks/pre-commit`, whose `*.sh|*.zsh` case patterns skip every extensionless script in `.local/bin/` — the most-edited files in the repo.)
- **tests/README.md** oversells in places: claims exit code 2 = "infrastructure error" (not implemented), lists a `fixtures/` directory that doesn't exist, and embeds a copy of the CI yaml (now a drift liability — link to the file instead).
- **`.vimrc` + `.vim/colors/*` are tracked but unlinked** — a full legacy vim-plug/copilot/gruvbox config (335 lines) that `doctor` flags as info on every run. Decide: link it as a deliberate vim fallback, or delete it (git history preserves it). Status quo is the worst option — it looks maintained but isn't. *[keep but mark legacy] → moved to `archive/vim/` with a README; doctor no longer flags it.*
- `nvim/README.md` mentions `telescope.lua` as the example plugin file; the repo uses snacks.nvim — trivial, but it's the first thing a reader sees.

## Smaller items, quickly

- `check-tools.sh` requires `curl` while `install-tools.sh` accepts curl _or_ wget — `make status` shows a red ✗ on a wget-only box the installer considers fine.
- `sysinfo` depends on `bc` (lines 59, 63), which install-tools doesn't install and Alpine lacks; `local x=$(...)` masks the failure so RAM prints as "` GB`". `awk` can do the arithmetic with no new dependency.
- `Makefile:51` passes `$(F)` to adopt unquoted — paths with spaces break at the make layer (adopt.sh itself handles them fine).
- `make_paths_relative` in `e` (line 120) produces _absolute_ paths — works fine, but the name and comment both say the opposite.
- `proj -c "my.app"`: user-supplied names aren't sanitized (only the basename default is, via `tr '. ' '__'`) — tmux rejects `.`/`:` in session names.
- envsync's `read -rp` prompts die silently on EOF under `set -e` (lines 394, 444) while the later editor prompt guards with `|| true` (line 520) — inconsistent; same pattern in clean/prune scripts.
- `.zshrc`'s `lt()` pipes through alias `r` — this only works because functions.zsh is sourced _after_ the alias is defined (aliases expand at function parse time in zsh). Fragile ordering worth a comment, or call `bat`/`less` explicitly.

---

## Priorities

If I had one afternoon:

1. **Fix install-tools error handling** (#5) — it breaks `make setup` on real Linux machines, and the fix is small.
2. **Make `restore` safe** (#7) and honor `--dry-run` in uninstall (#6) — these are the "safety net" features; they should be the most trustworthy code in the repo, and currently they're the least.
3. **Fix the four-line read loops** (#1) and **delete the vestigial `proj` wrapper** (#8) — both are five-minute fixes for real breakage. *[wdym delete proj?] → only the `proj()` shell **function** in functions.zsh, whose sole job was the removed `-d` flag (and whose substring check broke `proj my-dev`). The `proj` script is untouched; typing `proj` now runs it directly with identical behavior.*
4. **CI hardening:** add `pull_request` trigger + `make doctor` step; add zsh/tmux/nvim to the Alpine image (unlocks ~19 skipped tests); bake BATS into the image.
5. **Replace `e`'s porcelain parsing** (#2) and prune-branches' `git branch` parsing (#3) with plumbing commands.
6. **Docs pass:** CLAUDE.md aliases/scripts/test-list, doctor's glob-instead-of-list, decide `.vimrc`'s fate, track `lazy-lock.json`, document nvim ≥ 0.11.

Worth a think (not urgent): worktree removal of ignored files, `cp -RL` vs `-PR` for backups, default-branch-aware git aliases, real tests for install-tools.
