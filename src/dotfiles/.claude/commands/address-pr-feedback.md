---
description: Fetch all PR feedback (comments, reviews, inline threads) and address every issue without deferring
---

## Setup

Fetch **all three feedback types** (top-level comments, review comments, inline threads) by
running the helper script. It auto-detects owner/repo and the current branch's PR, paginates every
root and nested connection, and emits the complete JSON:

```
node ~/.claude/scripts/pr-feedback.mjs
```

Pass a PR number as the first arg to target a specific PR: `node ~/.claude/scripts/pr-feedback.mjs 736`.

Bot-authored comments and reviews (CI status dumps like cypress or semanticdiff) are dropped; the
output's `botFeedbackOmitted` field counts what was hidden. Fetch those with gh directly on the
rare occasion they matter. Bot-authored inline threads are always kept.

Outdated threads (`isOutdated: true`) with `isResolved: false` deserve particular attention: those
are typically feedback the author pushed fixes over, exactly what needs checking.

If `node` or the script is unavailable, reproduce its paginated GraphQL queries from the script
source. Never substitute a single `first:100` query and claim the result is complete.

## Review the feedback

Collect all feedback items across:

- `comments` — top-level PR conversation comments
- `reviews[].comments` — inline code comments attached to a review
- `reviewThreads[].comments` — inline threads (check `isResolved` and `isOutdated`)

For each item, classify it as:

- **Blocker** — must fix before merge
- **Suggestion** — non-blocking but worth doing
- **Question / FYI** — no code change needed; just a note or clarification

## Implement fixes

Work through every blocker and every suggestion you agree with. Do not defer. If a suggestion is clearly wrong or conflicts with the project's established patterns, skip it and note why.

Deduplicate inline comments by GraphQL `id`; the same comment can appear under both
`reviews[].comments` and `reviewThreads[].comments`.

For each change:

- Read the relevant file(s) before editing
- Make the change
- Re-read to verify correctness

## Commit and push

Group related changes into logical commits. Follow the existing commit style in this repo (`git log --oneline -10`). Stop after committing and wait for user approval before pushing.

## Post a PR comment

After pushing, post a PR comment that summarizes what was addressed. Format:

```
### PR feedback addressed

**Blockers fixed:**
- <item> — <brief description of change made>

**Suggestions implemented:**
- <item> — <brief description of change made>

**Skipped (with reason):**
- <item> — <reason: disagree / already handled / not applicable>
```

Use: `gh pr comment <number> --body "..."`
