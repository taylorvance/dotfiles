# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Critical Rules for Claude

**Run tests in Docker via make targets, not `bats` directly:**

- `make test` - Full suite in Docker
- `make test F=tests/unit/test-foo.bats` - Single file in Docker

**Don't duplicate documentation.** Each script in `src/dotfiles/.local/bin/`
documents itself via `-h`; keep that help text (and the README) current
instead of restating flags here.

## Repository Overview

This is a personal dotfiles repository using a custom symlink-based management system. Files in `src/dotfiles/` are symlinked to `~/` via a Makefile that calls the `src/symlink-manager.sh` helper script, based on paths listed in `config`.

The repository includes a comprehensive Docker-based test suite to safely verify changes without affecting your actual system.

## Key Commands

```bash
make setup         # Complete bootstrap: install tools + symlinks + git hooks
make install       # Only install CLI tools (no symlinks)
make link          # Only create symlinks (no tool installation)
make unlink        # Remove all symlinks
make status        # Check installation status of tools and dotfiles
make doctor        # Validate repo/config/script wiring without touching HOME
make shellcheck    # Lint all shell scripts
make adopt F=.path # Adopt an existing HOME path into src/dotfiles
make restore       # Interactively restore from backups
make macos         # Apply macOS system preferences (no-op elsewhere)
make help          # Show all available targets with descriptions
```

`make setup` detects the OS/package manager (brew/apt/dnf/pacman), installs
required and recommended tools, creates symlinks, and installs git hooks.
It is idempotent; conflicting files are backed up to
`.backups/YYYY-MM-DD_HH-MM-SS_PID/`.

`symlink-manager.sh` accepts `-n`/`--dry-run` for install, uninstall, and
restore previews.

### Testing (All Tests Run in Docker)

```bash
make test                                        # Run all tests in Docker
make test F=tests/unit/test-clean-script.bats    # Run single test file in Docker
make test-shell                                  # Drop into test container for debugging
make test-clean                                  # Remove test Docker images and containers
make dev-shell                                   # Ubuntu box with dotfiles pre-installed
```

### Adding New Dotfiles

1. Place file in `src/dotfiles/` matching desired path relative to `~/`
2. Add the relative path to `config` (one path per line)
3. Run `make link` to create the symlink
4. Run `make doctor` and `make test` to verify it works correctly

Or adopt an existing file: `make adopt F=.config/tool/config.toml` then `make link`.

## Architecture

### Core Structure

- **`Makefile`**: Command interface (`setup`, `link`, `status`, `doctor`, `test`, ...)
- **`src/install-tools.sh`**: Tool installation (macOS/Linux); failures are
  collected and summarized — optional-tool failures must never abort setup
- **`src/check-tools.sh`**: Tool status report (`make status`)
- **`src/doctor.sh`**: Static repo/config validator; discovers scripts by
  glob + shebang, so new scripts are covered automatically
- **`src/adopt.sh`**: Copies existing `$HOME` files into `src/dotfiles/` and appends `config`
- **`src/macos.sh`**: macOS `defaults` deviations from stock (`make macos`); exits as a no-op on other platforms
- **`src/symlink-manager.sh`**: Symlink operations (install/uninstall/status/restore)
- **`src/dotfiles/`**: The actual dotfiles, organized exactly as they appear under `~/`
- **`config`**: Paths to symlink (relative to both `src/dotfiles/` and `~/`)
- **`archive/`**: Retired configs kept for reference; not linked, not validated
- **`.githooks/`**: pre-commit (syntax-checks changed shell files, shebang-aware)
  and pre-push (runs `make test`)
- **`.github/workflows/test.yml`**: CI — doctor + shellcheck + Docker suite,
  on master pushes and PRs
- **`tests/`**: BATS test suite + Docker infrastructure (see `tests/README.md`)

### Tool Dependencies

- **Core**: nvim (>= 0.11 for the nvim config), git, tmux, zsh, curl/wget, gcc/make, unzip
- **Recommended/optional CLI**: fzf, zoxide, eza, fd, ripgrep, delta, atuin, bat, starship, mise, lazygit
- **Development**: node/npm (via mise; global versions in `.config/mise/config.toml`), python3; **Optional**: ollama, dotnet, php
- **Note**: All tools have graceful fallbacks in `.zshrc` if not installed

### Custom Scripts (`src/dotfiles/.local/bin/`)

Run any of these with `-h` for full usage — the help text is the source of truth.

- **`e`** — git-aware editor wrapper; composable file sets (`-m/-u/-a/-d/-r`)
  AND content (`-g`)/name (`-n`) filters, `file:line` support, piped input,
  `-` for stdin-as-content, fzf via `-i`
- **`envsync`** — find sample env files, report/copy missing variables
  (`-d` also diffs values)
- **`clean`** — remove dependency/cache dirs with a size report
- **`tmp`** — timestamped scratch workspaces (cd handled by the `tmp()`
  wrapper in `.zsh/functions.zsh`)
- **`proj`** — tmux session manager (picker/attach/create/kill)
- **`git-prune-branches`** — delete merged/gone/squash-merged branches;
  auto-discovered as `git prune-branches`; skips branches checked out in worktrees
- **`git-prune-worktrees`** — remove worktrees synced with upstream; flags
  `+N ignored` files that forced removal would delete
- **`sysinfo`** — hardware/OS summary (POSIX sh; everything else is bash)

Conventions shared by the interactive scripts: `-n` dry-run; `y/N/i` prompts
(apply all / abort / fzf multi-select); EOF at a prompt aborts safely;
bash 3.2 compatible (parallel arrays, no associative arrays).

### Configuration Files

- **`.zshrc`** — antigen + oh-my-zsh when present, with explicit fallbacks
  (history settings, arrow-key search widgets) so a bare zsh still behaves;
  vi mode with `jk`/`kj` escape; starship prompt (`.config/starship.toml`);
  runtimes via mise (nvm as fallback); modern CLI tools guarded by
  `command -v`. Local overrides: `~/.zshrc.local`
- **`.zsh/functions.zsh`** — `tmp` wrapper, `mkcd`, `extract`, `backup`,
  `fcd`, `lt`, `lsrepos`, `gw`, `raw`
- **nvim** (`.config/nvim/`) — lazy.nvim, requires nvim 0.11+; plugin
  versions pinned via tracked `lazy-lock.json`; see `.config/nvim/README.md`
- **`.gitconfig`** — aliases (see the file; `db` resolves the remote default
  branch and powers `smp`/`fmom`/`from`); delta pager; `user.useConfigOnly`
  with email set per-repo or in `~/.gitconfig.local`
- **`.tmux.conf`** — `C-Space` prefix, vi copy mode, TPM plugins
  (resurrect/continuum/yank); full cheat sheet in the file header

## Development Notes

### When Modifying Scripts

- Source scripts are in `src/`; custom scripts in `src/dotfiles/.local/bin/`
  are symlinked into `~/.local/bin/`, so changes affect the live environment
  immediately
- Update the script's `-h` help text (and README/CLAUDE.md if behavior
  categories change) in the same commit
- **IMPORTANT**: Always run `make doctor` and `make shellcheck` after
  modifying scripts/config. Run `make test` for the full Docker suite when
  Docker is available.

### Working with Config

- The `config` file can specify individual files or entire directories
- Directory entries create a single symlink to the directory (not recursive individual symlinks)
- Individual file symlinks allow keeping untracked files in the same directory

### Testing Workflow

1. **Make changes**: Edit files in `src/` or `src/dotfiles/`
2. **Test**: `make doctor` + `make shellcheck` locally, then `make test`
   (all) or `make test F=tests/unit/test-foo.bats` (single file) when Docker
   is available
3. **Debug issues**: Use `make test-shell` to explore the test environment
   interactively

Unit tests isolate themselves with temp directories:

```bash
setup() {
    export TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"
}

teardown() {
    rm -rf "$TEST_DIR"
}
```

Follow this pattern when adding new tests. See existing tests in `tests/unit/` for examples.
