---
description: Fetch all PR feedback (comments, reviews, inline threads) and address every issue without deferring
---

## Setup

Fetch **all three feedback types** (top-level comments, review comments, inline threads) in one shot by running the helper script — it auto-detects owner/repo and the current branch's PR and emits the full JSON:

```
node ~/.claude/scripts/pr-feedback.mjs
```

Pass a PR number as the first arg to target a specific PR: `node ~/.claude/scripts/pr-feedback.mjs 736`.

If `node` or the script is unavailable, fall back to the raw GraphQL call it wraps — get the PR number, owner, and repo first (`gh pr view --json number` + `gh repo view --json owner,name`), then:

```
gh api graphql -f query='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){comments(first:100){nodes{author{login}body createdAt}}reviews(first:100){nodes{author{login}state body submittedAt comments(first:100){nodes{author{login}body path line createdAt}}}}reviewThreads(first:100){nodes{isResolved isOutdated comments(first:100){nodes{author{login}body path line createdAt}}}}}}}' -f owner=OWNER -f repo=REPO -F number=PR_NUMBER
```

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
