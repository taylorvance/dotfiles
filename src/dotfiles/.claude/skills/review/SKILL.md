---
name: review
description: Review the current branch diff (or a given PR) before merging — ticket-grounded, uses the repo's own reviewer agents when defined, verifies findings, reports one line each
---

Review the branch diff before merging: ground it in the ticket the branch implements, use the
repo's own review machinery where it exists, verify every finding against source, report tersely.

Load `humans-dont-like-to-read` now — it is the output contract and defines the finding-line shape.

## 1. Scope the diff

- Default branch: `git default` (dotfiles alias), falling back to
  `git symbolic-ref --short refs/remotes/origin/HEAD`.
- `git diff <default>...HEAD --name-only` for changed files, `git log <default>..HEAD --oneline`
  for commit context. Empty diff → say so and stop.
- If `$ARGUMENTS` names a PR number or another branch, review that instead — in a worktree, never
  by switching the checkout.

## 2. Ticket + PR context

- Extract a Jira key (`[A-Z]+-\d+`) from, in order: branch name, last commit subject, PR title and
  body (`gh pr list --head "$(git branch --show-current)" --json number,title,body,url`).
- If a key is found and an Atlassian tool is available, fetch the ticket; capture summary and
  acceptance criteria. Otherwise proceed and record the gap under `### Not verified`.

## 3. Repo-specific review machinery — discover, don't assume

- **`.claude/agents/`**: if reviewer agents exist (code-reviewer, security-auditor, domain
  specialists), classify the changed files, then spawn the relevant agents in parallel in a single
  message. Brief each with the ticket context, the exact changed-file list, and "stay in ticket
  scope; out-of-scope observations go under Scope creep" — so none re-derive the diff and drift.
  No agents defined → do the review yourself with the same scope discipline.
- **Repo `CLAUDE.md` and `.claude/rules/`**: read the sections relevant to the touched areas.
- **A repo-local `/review` command or review config**: its dispatch rules (security-sensitive
  paths, extra specialists, domain checks, report add-ons) override these defaults.

## 4. Verify before reporting

For each candidate finding, read the actual source and confirm: the cited line at the reviewed
revision contains the code the finding names (not a hunk header or counted offset); the flagged
code is really a problem; it isn't already addressed elsewhere in the diff; acceptance-criteria
claims match the actual ticket text. Correct or drop anything that doesn't hold up.

You assign the final P-labels in this pass — specialist agents' severities are input, not binding.
The label is the decision it drives: **P1** you'd block the merge over it · **P2** fix warranted,
wouldn't block · **P3** worth mentioning, wouldn't insist.
Challenge each label against the rubric, in either direction: promote what a specialist undersold,
demote a P1 that wouldn't actually block the merge, and drop a P3 you wouldn't genuinely raise
with a colleague — it never becomes a finding.
Merge duplicates: when specialists report the same defect, it becomes one line at the label you
judge correct.

Order the final list by severity — all P1s, then P2s, then P3s — and by impact within each
severity. This ranked order is what gets numbered in the report.

## 5. Report

Per the output contract, print the whole report as one fenced code block of raw markdown syntax,
copyable verbatim into a PR comment. One numbered line per finding, severity leading each line,
sections with nothing in them deleted (never kept with "none"):

    ## Review: <branch> (<ticket-key or "no ticket">)
    ### Findings                <- one numbered flat list in your step-4 rank
    ### Acceptance criteria    <- unmet or partially-met only, with evidence
    ### Scope creep
    ### Not verified           <- every check that couldn't run, and what blocked it
    ### Verdict
    ship | needs fixes | blocked

**Never report `ship` for a check that couldn't run** — an audit that didn't happen must not read
as one that passed.

## Constraints

- Read-only: never modify files.
- Specialist agents report to you in full; compression happens on the way out. Never drop a
  finding, caveat, or failing check to hit a budget.
