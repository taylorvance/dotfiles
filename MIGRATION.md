# One-time migration: vendored plugins (Aug 2026)

Antigen, oh-my-zsh, and TPM were retired in favor of commit-pinned git
submodules (see the "Vendor zsh/tmux plugins as pinned submodules" commit).
Each machine needs this once, after pulling:

1. **Link** (syncs submodules, links `~/.zsh/plugins` + `~/.tmux/plugins`;
   the old plugins dir is auto-backed up to `.backups/`):

   ```bash
   make link
   ```

2. **Remove antigen leftovers** (brew package where present, loader, cache)
   and the orphaned global-gitignore symlink (it moved to
   `~/.config/git/ignore`):

   ```bash
   brew uninstall antigen 2>/dev/null
   rm -rf ~/.zsh/antigen ~/.zsh/antigen.zsh ~/.antigen
   rm -f ~/.gitignore
   ```

3. **Reset tmux onto the new config** — sessions survive via resurrect:
   - `prefix + C-s` (save layout; works on the old config too)
   - `tmux kill-server`
   - `proj <name>` — restores everything onto a fresh server

   Don't reload with `prefix + C-r` before the reset: the old in-memory
   config still has resurrect's restore shadowing that key.

4. **Sanity check**: open a new shell and type a bogus command — red
   syntax highlighting means the vendored plugins are live.

Open programs in restored panes come back as idle shells in the right
directory (resurrect doesn't relaunch arbitrary programs).

Delete this file once every machine has migrated.
