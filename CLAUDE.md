# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository using a custom symlink-based management system. Files in `home-away-from-HOME/` are symlinked to `~/` via a Makefile that calls the `bin/symlink-manager.sh` helper script, based on paths listed in `config`.

## Key Commands

### Installation
```bash
make setup
```
- Creates symlinks from `home-away-from-HOME/` to `~/` for files listed in `config`
- Idempotent: safe to run multiple times
- Backs up conflicting files to `backups/YYYY-MM-DD_HH-MM-SS_PID/`
- Only symlinks files/directories specified in `config`

### Other Make Targets
```bash
make help       # Show all available targets with descriptions
make status     # Check installation status of all dotfiles
make teardown   # Remove all symlinks
make restore    # Interactively restore from backups
```

### Adding New Dotfiles
1. Place file in `home-away-from-HOME/` matching desired path relative to `~/`
2. Add the relative path to `config` (one path per line)
3. Run `make setup` to create the symlink

## Architecture

### Core Structure
- **`Makefile`**: Standard API with targets: `setup`, `teardown`, `status`, `restore`, `help`
- **`bin/symlink-manager.sh`**: Helper script that handles symlink operations (install, uninstall, status, restore)
- **`home-away-from-HOME/`**: Source directory containing all dotfiles, organized exactly as they should appear under `~/`
- **`config`**: Text file listing paths to symlink (relative to `home-away-from-HOME/` and `~/`)
- **`backups/`**: Auto-generated backup directory for conflicting files

### Custom Scripts (`home-away-from-HOME/.local/bin/`)

**`e`** - Git-aware editor wrapper (enhanced file opener)
- `e -m`: Open modified git files
- `e -u`: Open untracked files
- `e -mu`: Open both modified and untracked
- `e -g PATTERN`: Open files matching pattern (uses `git grep` in repos)
- `e -d [REF]`: Open files changed from default branch or specified ref
- `e -i`: Interactive selection with fzf
- Supports piped input: `find . -name "*.py" | e`
- Detects default branch automatically (main/master)
- Falls back to regular `grep` outside git repos

### Configuration Files

**Shell (`.zshrc`)**
- Uses Antigen plugin manager with oh-my-zsh
- Vi mode enabled with `jk`/`kj` escape to normal mode
- Custom theme showing user@host, path, git branch, and vi mode
- Key bindings: ↑/↓ for history search, `^r` for incremental search
- Aliases: `r` (bat/less), `tree2` (filtered tree), `python` (python3)
- Integrations: fzf (multi-select by default), nvm
- Default editor: `nvim`

**Neovim (`.config/nvim/`)**
- Uses lazy.nvim plugin manager (bootstrapped via `lua/config/lazy.lua`)
- Structure: `init.vim` → `lazy.lua` → `plugins/init.lua`
- Plugins can be extended in separate `.lua` files in `plugins/`

**Git (`.gitconfig`)**
- Aliases: `st`, `di`, `ci`, `br`, `co`, `g` (enhanced grep), `lg` (graph log)
- Default editor: `nvim`
- Diff/merge tool: `nvimdiff`
- Extended regex and line numbers enabled for `git grep`

## Development Notes

### When Modifying Scripts
- Custom scripts in `.local/bin/` are symlinked to `~/.local/bin/` (in PATH)
- Changes to these scripts affect the live environment immediately
- The `e` script is referenced in `.zshrc` comments as the sophisticated "edit" command

### Working with Config
- The `config` file can specify individual files or entire directories
- Directory symlinks are recursive (all contents linked)
- Individual file symlinks allow keeping untracked files in the same directory
