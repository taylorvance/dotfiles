# Global agent instructions (all machines)

## Commit message format

Commits should include a one-line summary of the change, optionally followed by a blank line and
brief bullet points.

## Code and docs

- Update documentation, internal help, README files, and agent guidance made stale by a change.
- In TypeScript, prefer enums (or `as const` maps when enums are unavailable) for flags,
  constants, and state values unless the repository's style differs.

## Hooks

Mechanically checkable rules below are enforced by shared hooks (`~/.agents/hooks`, see
`agent-hook -h`). A denial is the rule firing, not a glitch: fix the command; never retry it
verbatim or route around the hook. Every denial is logged (`agent-hook -s` tallies them); a
rule that has not fired in ninety days is retired from the hook and kept only as prose.

## Git

- Use `git switch` and `git restore`, never `git checkout` (hook-enforced).
- Run plain git from the repository root: no `git -C`, no inline `cd` (hook-enforced).
- No AI attribution or co-author footers on commits or pull requests (hook-enforced).

## PRs & reviews

- Never push or open PRs without my explicit consent. Open PRs as one clean commit; push review
  fixes as separate commits (squash at merge).
- Never post a PR comment claiming fixes until the code is committed and pushed.
- When asked about PR feedback, always check all three sources: PR comments, inline review
  comments, and reviews.
- When addressing PR feedback, implement directly related non-blocking suggestions that you agree
  with.
- Post PR review feedback with `gh pr review`, never `gh pr comment` (hook-enforced). The review
  flag carries the verdict, so the posted body states none of its own. Non-blocking nits ride in
  the approving review rather than downgrading it to `--comment`.
- Review other people's PRs in a git worktree at `~/dev/worktrees/<repo>/<slug>` (path and slug
  hook-enforced); never switch my checkout. Copy only ignored environment files required for
  validation, preserve their permissions, and ensure they remain untracked.
- Number PR items without the `#` sign (hook-enforced; GitHub auto-links `#N`).
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
- Keep entries short: at most two sentences per field, and state the decision reached rather than
  the deliberation that reached it. Give one reason under `Rationale`, the one that would change a
  future maintainer's mind. Omit a field instead of padding it. Length is not thoroughness here;
  a long entry usually means the decision is still being argued.
- Keep entries newest-first: insert new entries immediately below the introductory text; never
  append them to the end (order and field vocabulary hook-enforced; fields over two sentences or three lines nudged).
- Legacy entries do not need every current field. Normalize structure when convenient, but never
  invent historical rationale or consequences. Update an old entry when it is relied upon,
  clarified, or superseded.
- When replacing a decision, add the replacement at the top, change the old status to
  `superseded`, and identify the replacement under `Refs`.
- A decision declined on its own goes in as `rejected`, so a later session does not re-propose it
  cold. An option that merely lost to a winner belongs in that winner's `Alternatives`, not its own
  entry. There is no `proposed`: a deferral is a decision, recorded `accepted` with the trigger
  that would revisit it.

The following fields are the entry's whole vocabulary; never invent new ones.

Use this template, omitting fields that genuinely do not apply:

```markdown
## YYYY-MM-DD Title

- Status: accepted | superseded | rejected
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
