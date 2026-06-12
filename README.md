# Taylor's dotfiles

These are my dotfiles. There are many like them, but these are mine.

## Why?

I'm reinventing the wheel with this dotfile management solution. There are many tools that do what I need and much more. But that's just it. I want a tool that does exactly what I need and no more. I also relish the learning opportunity.

The [bare git repo](https://www.atlassian.com/git/tutorials/dotfiles) approach is indeed elegant, but I have two gripes. You have to use an alias instead of using the git command (like `config diff`); and it doesn't allow you to store a README in the repo directory. I don't want to clutter my home with helper files that are specific to dotfile management.

[Dotbot](https://www.anishathalye.com/2014/08/03/managing-your-dotfiles/) was attractive--in fact, my solution is based on my cursory understanding of its philosophy--but I want to do things MY WAY dammit.

### My Way

The essence of my solution is this. Load up `src/dotfiles/` with all of your dotfiles, named and organized exactly as you want them to appear relative to `$HOME` (`~/`). Add a reference to that filepath in the `config` file. Then `install` to create symlinks automatically.

## Getting Started

### Installation

Simply clone the repo and run `make setup`.

```
git clone https://github.com/taylorvance/dotfiles.git && cd dotfiles && make setup
```

This will install required CLI tools (nvim, git, tmux, zsh, etc.) and create symlinks in your home directory for everything located in `src/dotfiles/` and configured in `config`. If there are any conflicts\*, your original files will be backed up in `.backups/` with full path preservation.

Installation is [idempotent](https://en.wikipedia.org/wiki/Idempotence), which is a [word](https://github.com/anishathalye/dotfiles) [that](https://medium.com/@webprolific/getting-started-with-dotfiles-43c3602fd789) [dotfile](https://umanovskis.se/blog/post/dotfiles/) [authors](https://www.geekytidbits.com/dotfiles/) [love](https://unhexium.net/dotfiles/the-dotfile-drama/) [to](https://bananamafia.dev/post/dotfile-deployment/) [flaunt](https://www.evanjones.ca/dotfiles-personal-software-configuration.html).

_\* If the file has already been installed/symlinked, it will be skipped. You will not lose local changes to installed files._

### Testing Your Changes

Before deploying changes to your actual system, test them safely in Docker:

```bash
make doctor            # Fast local validation, no Docker
make test              # Run all tests in Docker
make test-shell        # Interactive debugging
```

**All tests passing?** ✓ Safe to deploy!
See [tests/README.md](tests/README.md) for detailed testing documentation.

### Available Commands

Run `make help` to see all available commands:

**Setup & Management:**

- `make setup` - Complete bootstrap: install tools + create symlinks
- `make install` - Install required + recommended CLI tools (prompts before optional language tools)
- `make link` - Create symlinks only (no tool installation)
- `make unlink` - Remove all dotfile symlinks
- `make status` - Show installation status of tools and dotfiles
- `make doctor` - Validate repo wiring and script syntax without touching `$HOME`
- `make shellcheck` - Lint all shell scripts (requires shellcheck)
- `make adopt F=.path` - Copy an existing `$HOME` path into `src/dotfiles/`, add it to `config`, and preview linking
- `make restore` - Restore files from a backup directory

**Testing (safe - runs in Docker, never touches your system):**

- `make test` - Run all tests in Docker
- `make test-shell` - Interactive debugging shell
- `make test-clean` - Remove Docker test artifacts

### Adding new dotfiles

1. Place the dotfile in `src/dotfiles/` exactly as it should appear relative to your own home directory. In other words, pretend `src/dotfiles/` is `~/`.

```
|-- dotfiles
    |-- src
        |-- dotfiles
            |-- .my-whole-directory
            |   |-- file1.cfg
            |   |-- file2.cfg
            |-- .config
            |   |-- nvim
            |       |-- init.vim
            |-- .zshrc
```

2. Add a line to `config`. You can link specific files or whole directories.

```
.my-whole-directory
.config/nvim
.zshrc
```

3. Test your changes: `make test`

Or adopt an existing file from your home directory:

```bash
make adopt F=.config/tool/config.toml
make link
```

## What's Included

### Tools Installed

Core tools are nvim, git, tmux, zsh, curl/wget, unzip, and build tools where needed. The installer also attempts to install recommended CLI tools (fzf, zoxide, eza, fd, ripgrep, delta, atuin, bat, starship) and development tools (mise for node — global versions live in `~/.config/mise/config.toml` — plus python3), but the shell config is designed to degrade gracefully when optional tools are missing.

### Custom Scripts (`~/.local/bin/`)

- **`e`** - Git-aware editor wrapper with composable filters
- **`proj`** - tmux session manager
- **`tmp`** - Quick temporary workspace creator
- **`clean`** - Remove common dependency/cache directories
- **`envsync`** - Compare `.env` files against their sample counterparts
- **`git-prune-branches`** - Remove stale local git branches
- **`git-prune-worktrees`** - Remove synced git worktrees
- **`sysinfo`** - Quick system information summary

Each script documents itself — run it with `-h` for full usage.

### Configurations

- **zsh** - Vi mode, custom prompt, modern CLI integrations, graceful fallbacks
- **nvim** - lazy.nvim plugin manager
- **git** - Common aliases, delta diff integration
- **tmux** - `C-Space` prefix, vim-like navigation

## Project Structure

```
dotfiles/
├── src/                    # All source code
│   ├── install-tools.sh    # Tool installation script
│   ├── check-tools.sh      # Tool verification script
│   ├── doctor.sh           # Local repo/config validator
│   ├── adopt.sh            # Adopt existing home files into src/dotfiles/
│   ├── symlink-manager.sh  # Symlink management (install/uninstall/status/restore)
│   └── dotfiles/           # Your actual dotfiles
│       ├── .config/
│       ├── .local/bin/
│       ├── .zshrc
│       ├── .tmux.conf
│       └── .gitconfig
├── tests/                  # Comprehensive test suite
│   ├── docker/             # Docker infrastructure (Alpine test image, Ubuntu dev image)
│   ├── unit/               # Unit tests
│   ├── integration/        # Integration tests
│   ├── test-runner.sh      # Test orchestration
│   └── README.md           # Testing documentation
├── archive/                # Retired configs kept for reference (not linked)
├── .backups/               # Auto-generated backups
│   └── 2025-01-20_10-30-45_12345/
│       └── .zshrc          # Your original files
├── config                  # Paths to symlink
├── Makefile                # Command interface
├── CLAUDE.md               # AI assistant instructions
└── README.md               # This file
```

### Backups

When you run `make setup`, files that would be overwritten are automatically backed up to `.backups/` with full path preservation. Each backup is in a timestamped directory (format: `YYYY-MM-DD_HH-MM-SS_PID`) so you never lose data.

Use `make restore` to interactively restore from any backup.

### Config File

`config` is a text file that lists which files/directories to symlink. One path per line, relative to both `src/dotfiles/` and `~/`. Empty lines and lines beginning with `#` are ignored.

**Specific files:** `.config/nvim/init.vim` links that file at `~/.config/nvim/init.vim` while leaving the rest of `~/.config/nvim` intact.

**Whole directories:** `.config/nvim` links the entire directory at `~/.config/nvim/`.

**Note:** When linking a directory, any existing files in `~/` at that path will be backed up. To maintain untracked files in a directory, configure specific files instead of the whole directory.

### Forking

All of the content specific to my setup is in `src/dotfiles/` and `config`. To start fresh:

1. Empty out `src/dotfiles/` and `config`
2. Add your own dotfiles to `src/dotfiles/`
3. Reference them in `config`
4. Run `make doctor` and `make test` to verify
5. Run `make setup` to deploy

## Contributing

This is a personal dotfiles repo, but the testing infrastructure could be useful for others. Feel free to adapt the test suite for your own dotfiles!
