# Global Claude instructions

@~/.agents/AGENTS.md

## PRs & reviews

Shared PR rules live in `~/.agents/AGENTS.md`; only Claude Code specifics belong here.

- When checking a PR for feedback (assume the PR for the current checked-out branch), run the
  helper script: `node ~/.claude/scripts/pr-feedback.mjs [PR_NUMBER]`. It auto-detects owner/repo
  and the current branch's PR (works from any repo), then emits the full
  comments+reviews+reviewThreads JSON. Bot-authored comments and reviews (CI status dumps) are
  dropped and counted in `botFeedbackOmitted`; fetch those with gh directly on the rare occasion
  they matter. Pass a PR number to target a specific PR. If `node` or the script is unavailable,
  reproduce its paginated GraphQL queries (see the script source).
- Worktree permission scoping outside the repo comes from `permissions.additionalDirectories`
  (`~/dev/worktrees` in `~/.claude/settings.json`). Never place a worktree under any `.claude/`
  path: every file edit inside one trips the "edit its own settings" approval. Don't use
  EnterWorktree's `name` mode (it creates under `.claude/worktrees/`); entering an existing
  worktree via its `path` param is fine.

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
