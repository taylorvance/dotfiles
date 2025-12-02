# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository using a custom symlink-based management system. Files in `src/dotfiles/` are symlinked to `~/` via a Makefile that calls the `src/symlink-manager.sh` helper script, based on paths listed in `config`.

The repository includes a comprehensive Docker-based test suite to safely verify changes without affecting your actual system.

## Key Commands

### Fresh Machine Setup

```bash
make setup
```

- **Complete bootstrap**: Installs all required tools + creates symlinks
- Detects OS (macOS/Linux) and package manager (brew/apt/dnf/pacman)
- Installs: nvim, git, tmux, zsh, fzf, bat, zoxide, eza, fd, ripgrep, delta, atuin, node, python3
- Creates symlinks from `src/dotfiles/` to `~/` for files listed in `config`
- Idempotent: safe to run multiple times
- Backs up conflicting files to `backups/YYYY-MM-DD_HH-MM-SS_PID/`

### Individual Operations

```bash
make install       # Only install CLI tools (no symlinks)
make link          # Only create symlinks (no tool installation)
make unlink        # Remove all symlinks
make status        # Check installation status of all dotfiles
make restore       # Interactively restore from backups
make help          # Show all available targets with descriptions
```

### Testing (Safe, Never Touches Your System)

```bash
make test              # Run all tests in Docker (unit + integration + config verification)
make test-unit         # Run only unit tests (fast, ~10s)
make test-integration  # Run integration tests (medium, ~30s)
make test-configs      # Run config verification tests (nvim, tmux, zsh)
make test-shell        # Drop into test container for interactive debugging
make test-clean        # Remove test Docker images and containers
```

### Adding New Dotfiles

1. Place file in `src/dotfiles/` matching desired path relative to `~/`
2. Add the relative path to `config` (one path per line)
3. Run `make link` to create the symlink
4. Run `make test` to verify it works correctly

## Architecture

### Core Structure

- **`Makefile`**: Standard API with targets: `setup`, `link`, `unlink`, `status`, `restore`, `test`, `help`
- **`src/install-tools.sh`**: Tool installation script supporting macOS (Homebrew) and Linux (apt/dnf/pacman)
- **`src/check-tools.sh`**: Verification script that checks installation status of all tools
- **`src/symlink-manager.sh`**: Helper script that handles symlink operations (install, uninstall, status, restore)
- **`src/dotfiles/`**: Source directory containing all dotfiles, organized exactly as they should appear under `~/`
- **`config`**: Text file listing paths to symlink (relative to `src/dotfiles/` and `~/`)
- **`backups/`**: Auto-generated backup directory for conflicting files
- **`tests/`**: Comprehensive test suite with Docker infrastructure

### Tool Dependencies

- **Core**: nvim, git, tmux, zsh, fzf, curl/wget, gcc/make, unzip
- **Modern CLI**: zoxide, eza, fd, ripgrep, delta, atuin, bat
- **Development**: node/npm, python3
- **Optional**: ollama (AI completions), dotnet (C#), php (PHP)
- **Note**: All tools have graceful fallbacks in `.zshrc` if not installed

### Test Suite Architecture

**`tests/docker/`** - Docker infrastructure for isolated testing

- **`Dockerfile.alpine`**: Fast, minimal Alpine Linux base (~200MB, tests run in ~45s)
- **`Dockerfile.ubuntu`**: Ubuntu base for broader compatibility testing

**`tests/unit/`** - Unit tests for individual components

- **`test-symlink-manager.bats`**: Tests symlink creation, conflict handling, backups, status checking
- **`test-install-tools.bats`**: Tests tool installation logic and error handling

**`tests/integration/`** - End-to-end integration tests

- **`test-fresh-setup.bats`**: Fresh system installation scenarios
- **`test-idempotency.bats`**: Verify safe re-running of operations
- **`test-conflicts.bats`**: Conflict detection, backup creation, and restore functionality
- **`test-configs.bats`**: Verification that nvim, tmux, zsh, git configs work correctly

**`tests/test-runner.sh`** - Test orchestration script

- Builds Docker container with dotfiles
- Installs BATS testing framework automatically
- Runs selected test suites
- Provides interactive shell for debugging

### Custom Scripts (`src/dotfiles/.local/bin/`)

**`e`** - Git-aware editor wrapper with composable filters

Uses a **composable filter model** where all filters AND together:

- **File sets**: `-m` (modified), `-u` (untracked), `-a` (all tracked), `-d [REF]` (diff), `--history [N]` (recent)
- **Content filter**: `-g PATTERN` (files containing pattern)
- **Name filter**: `-n PATTERN` (filename matches regex)
- **Positional filters**: Additional filename substring filters
- **Interactive**: `-i` (fzf selection)

**Composition examples:**
- `e -m -g TODO`: Modified files containing "TODO"
- `e -u -n test`: Untracked files with "test" in name
- `e -g TODO test`: Files containing "TODO" with "test" in filename
- `e -m -g TODO -n .py`: Modified Python files containing "TODO"
- `e -a component`: All tracked files with "component" in filename
- `e -mui`: Modified+untracked files, interactive selection

**Basic usage:**
- `e file.txt`: Open or create file
- `e -m`, `e -u`, `e -mu`: Modified/untracked files
- `e -d`, `e -d dev`: Diff from branch
- `e -ai`: Browse all tracked files
- Piped input: `find . -name "*.py" | e`
- Detects default branch automatically (main/master)
- Falls back to regular `grep`/`find` outside git repos

### Configuration Files

**Shell (`.zshrc`)**

- Uses Antigen plugin manager with oh-my-zsh
- Vi mode enabled with `jk`/`kj` escape to normal mode
- Custom theme showing user@host, path, git branch, vi mode, command duration (configurable via `CMD_DURATION_THRESHOLD`), exit code
- Key bindings: ↑/↓ for history search, `^r` for atuin/history search
- Modern CLI tools: `zoxide` (z), `eza` (ls/ll/la/lt), `fd` (f), `ripgrep` (rg), `atuin` (history)
- Aliases: `r` (bat/less), `tree2` (filtered tree), `python` (python3)
- Functions: `mkcd`, `extract`, `backup`, `fcd` (fzf directory jump)
- Integrations: fzf (multi-select by default), nvm
- Default editor: `nvim`
- Graceful fallbacks if modern tools not installed

**Neovim (`.config/nvim/`)**

- Uses lazy.nvim plugin manager (bootstrapped via `lua/config/lazy.lua`)
- Structure: `init.vim` → `lazy.lua` → `plugins/init.lua`
- Plugins can be extended in separate `.lua` files in `plugins/`

**Git (`.gitconfig`)**

- Aliases: `st`, `di`, `ci`, `br`, `co`, `g` (enhanced grep), `lg` (graph log)
- Default editor: `nvim`
- Diff/merge tool: `nvimdiff`
- Delta integration: syntax-highlighted diffs, side-by-side view, line numbers
- Extended regex and line numbers enabled for `git grep`
- Global `.gitignore` for common patterns (macOS, IDEs, temp files, etc.)

**Tmux (`.tmux.conf`)**

- Prefix: `C-a` (instead of default `C-b`)
- Vim-like navigation: `h/j/k/l` for panes, `H/J/K/L` for resizing
- Smart splits: `|` and `-` open in current directory
- Vi copy mode with system clipboard integration (macOS: pbcopy)
- Status bar showing session, date/time
- Mouse support enabled
- Reload config: `prefix + r`

## Development Notes

### When Modifying Scripts

- Source scripts are in `src/` directory
- Custom scripts in `src/dotfiles/.local/bin/` are symlinked to `~/.local/bin/` (in PATH)
- Changes to these scripts affect the live environment immediately
- The `e` script is referenced in `.zshrc` comments as the sophisticated "edit" command
- **IMPORTANT**: Always run `make test` after modifying scripts to verify nothing broke

### Working with Config

- The `config` file can specify individual files or entire directories
- Directory symlinks are recursive (all contents linked)
- Individual file symlinks allow keeping untracked files in the same directory

### Testing Workflow

1. **Before modifying**: Run `make test` to establish baseline
2. **Make changes**: Edit files in `src/` or `src/dotfiles/`
3. **Test locally**: Use `make test-unit` for quick feedback during development
4. **Test fully**: Run `make test` for comprehensive verification
5. **Debug issues**: Use `make test-shell` to explore the test environment interactively
6. **Clean up**: Run `make test-clean` to remove Docker artifacts

### Test Suite Benefits

- **Safe**: Never touches your actual system, runs entirely in Docker
- **Fast**: Unit tests complete in ~10s, full suite in ~45s
- **Comprehensive**: Tests installation, symlinking, conflicts, backups, and actual config functionality
- **Debuggable**: Interactive shell mode for troubleshooting
- **CI-ready**: Exit codes and TAP format for future automation
