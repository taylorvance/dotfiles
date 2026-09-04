# Global agent instructions (all machines)

## Commit message format

Commits should include a one-line summary of the change, optionally followed by a blank line and
brief bullet points.

## Code and docs

- Update documentation, internal help, README files, and agent guidance made stale by a change.
- In TypeScript, prefer enums (or `as const` maps when enums are unavailable) for flags,
  constants, and state values unless the repository's style differs.

## Git

- Use `git switch` instead of `git checkout` to create or change branches.
- Run plain git from the repository root; do not use `git -C` or inline `cd`.
- Do not add AI attribution or co-author footers to commits or pull requests.

## PRs & reviews

- Never push or open PRs without my explicit consent. Open PRs as one clean commit; push review
  fixes as separate commits (squash at merge).
- Never post a PR comment claiming fixes until the code is committed and pushed.
- When asked about PR feedback, always check all three sources: PR comments, inline review
  comments, and reviews.
- When addressing PR feedback, implement directly related non-blocking suggestions that you agree
  with. Report unrelated improvements as scope creep instead of silently expanding the change.
- Post PR review feedback as a review, never a plain `gh pr comment`. The `gh pr review` flag
  carries the verdict, so omit the report's `### Verdict` line from the posted body. Non-blocking
  nits ride in the approving review rather than downgrading it to `--comment`.
- Review other people's PRs in a git worktree; never switch my checkout. Worktrees live OUTSIDE
  the repo at `~/dev/worktrees/<repo>/<slug>` via `git worktree add` (slug: letters/digits/hyphens
  only; `+` etc. break jest's unescaped `<rootDir>` ignore regexes). Never place them inside the
  repo tree either (jest haste maps, lint scripts, and watchers crawl nested worktrees). Copy only
  ignored environment files required for validation, preserve their permissions, and ensure they
  remain untracked.
- Numbering items in PR comments is fine, but never with the `#` sign (GitHub auto-links `#N` to
  issues/PRs).
- Do not request PR reviewers (`--reviewer`) unless asked.

## declog

Use `.declog.md` as the repository's decision log.

- If it exists, read it before significant architectural decisions and update it when the
  rationale would help a future maintainer.
- If it does not exist, create it with the first qualifying decision when the repository is
  clearly personal. In shared, organizational, or work repositories, ask before introducing it;
  if ownership is unclear, ask.
- Do not log routine implementation choices, easily reversible decisions, or facts already
  obvious from the code.
- Keep entries newest-first: insert new entries immediately below the introductory text; never
  append them to the end.
- Legacy entries do not need every current field. Normalize structure when convenient, but never
  invent historical rationale or consequences. Update an old entry when it is relied upon,
  clarified, or superseded.
- When replacing a decision, add the replacement at the top, change the old status to
  `superseded`, and identify the replacement under `Refs`.

Use this template, omitting fields that genuinely do not apply:

```markdown
## YYYY-MM-DD Title

- Status: proposed | accepted | superseded
- Topics:
- Refs:
- Decision:
- Rationale:
- Consequences:
- Alternatives:
```

## Working style

- Do not ask questions already answered by standing guidance. Read-only inspection does not need
  permission. A question such as "should I do X?" requests a recommendation, not authorization to
  mutate state; announce state changes before making them.
- Do not promise deferred actions. Perform an authorized action now, then reference the result.
- Do not ship an interim stopgap when the intended end state is known and inexpensive.
- Do not launch heavy multi-agent fan-out (workflow orchestration, deep research, wide parallel
  sweeps) without an upfront cost estimate and explicit approval. Dispatching the few agents or
  helpers a task's own skill calls for is ordinary work, not fan-out.
- Never store queryable external status in memory; query it live. Keep only non-queryable
  decisions, gotchas, and conflicts, and remove them when they cease to apply.
