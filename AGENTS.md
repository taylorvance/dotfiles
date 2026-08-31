# Dotfiles repository guidance

## Project model

- This is a personal, symlink-managed dotfiles repository. Treat `src/dotfiles/` as a model of
  `$HOME`: a file intended for `~/.config/tool/config` belongs at
  `src/dotfiles/.config/tool/config`.
- Paths listed in `config` are deployed from `src/dotfiles/` into `$HOME` by
  `src/symlink-manager.sh`; deployed files may therefore be symlinks whose edits immediately
  affect the repository.
- For any dotfile-related request, first inspect `config` and the corresponding path under
  `src/dotfiles/`. Assume the repository source is the intended edit target.
- Treat files under `$HOME` as live/deployed state. Read them when useful to compare or verify,
  but do not edit them unless the user explicitly requests a local-only change or the setting is
  intentionally untracked.
- If a relevant live file is not represented in `config` or `src/dotfiles/`, say so before
  changing it. Do not assume it should be adopted: some applications keep mutable,
  machine-specific state in otherwise useful configuration files.

## Working in this repository

- Read `.declog.md` before significant architectural decisions.
- Add new managed dotfiles under `src/dotfiles/`, add their relative paths to `config`, and use
  `make adopt F=.path` when adopting an existing home-directory file.
- Custom scripts live under `src/dotfiles/.local/bin/`; their `-h` output is the source of truth
  for user-facing behavior. Read and update it whenever changing or documenting a command's
  interface.
- Keep the README, tests, and agent guidance current when behavior changes.
- Standalone scripts target Bash 3.2 unless they are deliberately POSIX `sh`; interactive shell
  integration belongs in zsh.

## Verification

- Run `make doctor` and `make shellcheck` after modifying scripts or managed configuration.
- Run tests through Docker with `make test` or `make test F=tests/unit/test-name.bats`; do not run
  BATS directly on the host.
