# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Critical Rules for Claude

**Run tests in Docker via make targets, not `bats` directly:**
- `make test` - Full suite in Docker
- `make test F=tests/unit/test-foo.bats` - Single file in Docker

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
- Installs: nvim, git, tmux, zsh, fzf, bat, zoxide, eza, fd, ripgrep, delta, atuin, starship, node, python3
- Creates symlinks from `src/dotfiles/` to `~/` for files listed in `config`
- Idempotent: safe to run multiple times
- Backs up conflicting files to `.backups/YYYY-MM-DD_HH-MM-SS_PID/`

### Individual Operations

```bash
make install       # Only install CLI tools (no symlinks)
make link          # Only create symlinks (no tool installation)
make unlink        # Remove all symlinks
make status        # Check installation status of all dotfiles
make restore       # Interactively restore from backups
make help          # Show all available targets with descriptions
```

### Testing (All Tests Run in Docker)

```bash
make test                                        # Run all tests in Docker
make test F=tests/unit/test-clean-script.bats    # Run single test file in Docker
make test-shell                                  # Drop into test container for debugging
make test-clean                                  # Remove test Docker images and containers
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
- **`.backups/`**: Auto-generated backup directory for conflicting files
- **`tests/`**: Comprehensive test suite with Docker infrastructure

### Tool Dependencies

- **Core**: nvim, git, tmux, zsh, fzf, curl/wget, gcc/make, unzip
- **Modern CLI**: zoxide, eza, fd, ripgrep, delta, atuin, bat, starship
- **Development**: node/npm, python3
- **Optional**: ollama (AI completions), dotnet (C#), php (PHP)
- **Note**: All tools have graceful fallbacks in `.zshrc` if not installed

### Test Suite Architecture

**`tests/docker/`** - Docker infrastructure for isolated testing

- **`Dockerfile.alpine`**: Fast, minimal Alpine Linux base
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

### Unit Test Conventions

Tests run in Docker, but each test still isolates itself with temp directories for clean setup/teardown:

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

### Custom Scripts (`src/dotfiles/.local/bin/`)

**`clean`** - Remove build dependencies and cache directories

Reclaim disk space by removing common dependency folders across projects:

- **Basic usage**: `clean` - scan current directory's immediate subdirs
- **Recursive**: `clean -r` - search all nested directories
- **Dry run**: `clean -n` - show what would be deleted, no prompt
- **Custom path**: `clean ~/projects` - specify directory to scan
- **Prompt options**: `y` (delete all), `N` (abort), `i` (interactive fzf selection)
- **Targets**: `node_modules`, `__pycache__`, `.venv`, `venv`, `.pytest_cache`, `*.egg-info`
- **Features**:
  - Shows size of each directory, sorted largest first
  - Displays total reclaimable space
  - Interactive mode uses fzf for multi-select (TAB to select)

**`tmp`** - Quick temporary workspace creator

Create timestamped temporary directories for scratch work:

- **Basic usage**: `tmp` - create new temp dir and cd to it
- **Edit mode**: `tmp -e` - create temp dir, cd, and open `scratch.txt` in editor
- **Custom file**: `tmp -e test.py` - specify filename for syntax highlighting
- **List/select**: `tmp -l` - interactive picker of existing temp dirs
- **Recent**: `tmp -r` - cd to most recent temp directory
- **Delete**: `tmp -d` - interactively delete temp workspaces
- **Features**:
  - Timestamped directories: `/tmp/tmp-workspaces/YYYYMMDD-HHMMSS/`
  - Shell wrapper function handles cd and editor invocation
  - Perfect for quick experiments, scratch files, or temporary work

**`git-prune-branches`** - Remove local git branches that are no longer needed

Auto-discovered by git as `git prune-branches` (no alias needed):

- **Basic usage**: `git prune-branches` - find and delete stale branches
- **Dry run**: `git prune-branches -n` - show branches without prompting
- **Squash detection**: `git prune-branches -a` - also detect squash-merged branches (slower)
- **Prompt options**: `y` (delete all), `N` (abort, default), `i` (interactive fzf selection)
- **Branch states detected**:
  - `[merged]` — merged into default branch (safe `-d` delete)
  - `[gone]` — remote tracking branch was deleted (force `-D` delete)
  - `[merged, gone]` — both merged and remote deleted (most common after PR workflow)
  - `[squash-merged]` — changes integrated via squash/rebase, detected by `git cherry` (with `-a`)
- **Features**:
  - Auto-detects default branch (origin/HEAD, main, master)
  - Groups branches by state
  - Skips current and default branches
  - Bash 3.2 compatible (no associative arrays)

**`proj`** - Project-aware workflow manager with tmux integration

Combines **zoxide** (smart directory jumping) with **tmux sessions** for seamless project switching:

- **Basic usage**: `proj myproject` - cd to project + attach/create tmux session
- **Detach mode**: `proj -d backend` - cd without tmux (outputs cd command for shell wrapper)
- **List sessions**: `proj -l` - show all active project sessions
- **Kill session**: `proj -k myapp` - terminate a project session
- **Interactive picker**: `proj` - fzf picker of recent projects (via zoxide)
- **Features**:
  - One tmux session per project (named after directory)
  - Smart project matching via zoxide (learns your frequently used projects)
  - Works inside or outside tmux (switches or attaches intelligently)
  - Graceful fallbacks when tmux/zoxide not installed

**`e`** - Git-aware editor wrapper with composable filters

Uses a **composable filter model** where all filters AND together:

- **File sets**: `-m` (modified), `-u` (untracked), `-a` (all tracked), `-d [ARG]` (diff), `-r [N]` (recent)
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
- `e file.txt:42`: Open at line 42 (works with vim/nvim/emacs/nano/gedit/micro)
- `e docs/*.md`: Open multiple files via shell glob
- `e -m`, `e -u`, `e -mu`: Modified/untracked files
- `e -d`, `e -d dev`, `e -d branch1..branch2`: Diff (mirrors git diff)
- `e -r`, `e -r 20`: Recent files (default 10)
- `e -ai`: Browse all tracked files
- Detects default branch automatically (main/master)
- Falls back to regular `grep`/`find` outside git repos

**Piped input & grep integration:**
- `find . -name "*.py" | e`: Open found files
- `git ls-files | e`: Open tracked files
- `grep -rn "TODO" | fzf | e`: Select grep match, open at line number
- `grep -rn "pattern" src/ | e`: Open all matches at their line numbers

**Stdin as content (using `-`):**
- `echo "hello" | e -`: Open stdin content in new buffer
- `cat log.txt | e -`: View file content in editor
- `curl url | e -`: Edit fetched content
- `pbpaste | e -`: Edit clipboard content

### Configuration Files

**Shell (`.zshrc`)**

- Uses Antigen plugin manager with oh-my-zsh
- Vi mode enabled with `jk`/`kj` escape to normal mode
- Starship prompt (config in `.config/starship.toml`) with user@host, path, git branch, vi mode, command duration, exit code
- Key bindings: ↑/↓ for history search, `^r` for atuin/history search
- Modern CLI tools: `zoxide` (z), `eza` (ls/ll/la/lt), `fd` (f), `ripgrep` (rg), `atuin` (history)
- Aliases: `r` (bat/less), `python` (python3), `f` (fd)
- Functions: `mkcd`, `extract`, `backup`, `fcd` (fzf directory jump), `lt` (tree view), `gw` (git worktree cd)
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
- Directory entries create a single symlink to the directory (not recursive individual symlinks)
- Individual file symlinks allow keeping untracked files in the same directory

### Testing Workflow

1. **Make changes**: Edit files in `src/` or `src/dotfiles/`
2. **Test**: `make test` (all) or `make test F=tests/unit/test-foo.bats` (single file)
3. **Debug issues**: Use `make test-shell` to explore the test environment interactively
