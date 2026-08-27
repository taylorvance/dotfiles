# Global Claude instructions

@~/.codex/AGENTS.md

## PRs & reviews

- Never push or open PRs without my explicit consent. Open PRs as one clean commit; push review
  fixes as separate commits (squash at merge).
- Never post a PR comment claiming fixes until the code is committed and pushed.
- When checking a PR for feedback (assume the PR for the current checked-out branch), run the
  helper script: `node ~/.claude/scripts/pr-feedback.mjs [PR_NUMBER]`. It auto-detects owner/repo
  and the current branch's PR (works from any repo), then emits the full
  comments+reviews+reviewThreads JSON; pass a PR number to target a specific PR, and
  `--unresolved` to drop resolved/outdated threads on very large PRs. If `node` or the
  script is unavailable, reproduce its paginated GraphQL queries (see the script source).
- When asked about PR feedback, always check all three sources: PR comments, inline review
  comments, and reviews.
- When addressing PR feedback, implement directly related non-blocking suggestions that you agree
  with. Report unrelated improvements as scope creep instead of silently expanding the change.
- Post PR review feedback as a review, never a plain `gh pr comment`: `--request-changes` if any
  blocker, `--approve` only if I accepted an approve recommendation, else `--comment`.
- Review other people's PRs in a git worktree; never switch my checkout. Worktrees live OUTSIDE
  the repo at `~/dev/worktrees/<repo>/<slug>` via `git worktree add` (slug: letters/digits/hyphens
  only; `+` etc. break jest's unescaped `<rootDir>` ignore regexes). Never place my worktrees
  under any `.claude/` path (every file edit inside one trips the "edit its own settings"
  approval) or anywhere inside the repo tree (jest haste maps, lint scripts, and watchers crawl
  nested worktrees). Permission scoping outside the repo comes from
  `permissions.additionalDirectories` (`~/dev/worktrees` in `~/.claude/settings.json`). Don't use
  EnterWorktree's `name` mode (it creates under `.claude/worktrees/`); entering an existing
  worktree via its `path` param is fine. Copy only ignored environment files required for
  validation, preserve their permissions, and ensure they remain untracked.
- Numbering items in PR comments is fine, but never with the `#` sign (GitHub auto-links `#N` to
  issues/PRs).
- Do not request PR reviewers (`--reviewer`) unless asked.

## Shell & tools

- Never use deny- or ask-gated commands when allowed or builtin alternatives would suffice; prefer
  built-in tools over commands that require manual approval (e.g. python).
- Never use python to read or edit files. Use Read/grep/Edit directly, even for JSON.
- Use a heredoc for `gh api graphql` calls to avoid brace-expansion prompts.
- Never bundle rg's `-r` into flag clusters (`-ril` = `--replace=il`); it silently rewrites match
  output.
- To prevent false-positive "quoted characters in flag names" warnings, avoid `echo "---"` and
  similar in your shell commands.

## Machine-local instructions

Untracked, may not exist on every machine (work org details, private IDs):

@~/.claude/CLAUDE.local.md
