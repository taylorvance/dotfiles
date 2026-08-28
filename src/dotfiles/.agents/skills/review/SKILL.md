---
name: review
description: Review the current branch diff (or a given PR) before merging: ticket-grounded, dispatches whatever reviewers the repo and the client provide, verifies every finding, reports one line each
---

Review the branch diff before merging: ground it in the ticket the branch implements, use the
repo's own review machinery where it exists, verify every finding against source, report tersely.

Load the `humans-dont-like-to-read` skill now (if your harness has no skill loader, read its
SKILL.md from the sibling directory) — it is the output contract and defines the finding-line shape.

## 1. Scope the diff

- Default branch: `git default` (dotfiles alias), falling back to
  `git symbolic-ref --short refs/remotes/origin/HEAD`.
- `git diff <default>...HEAD --name-only` for changed files, `git log <default>..HEAD --oneline`
  for commit context. Empty diff → say so and stop.
- If the invocation names a PR number or another branch, review that instead — in a worktree,
  never by switching the checkout.

## 2. Ticket + PR context

- Extract a Jira key (`[A-Z]+-\d+`) from, in order: branch name, last commit subject, PR title and
  body (`gh pr list --head "$(git branch --show-current)" --json number,title,body,url`).
- If a key is found and an Atlassian tool is available, fetch the ticket; capture summary and
  acceptance criteria. Otherwise proceed and record the gap under `### Not verified`.

## 3. Review machinery: discover, don't assume

Invoking this skill is the request to dispatch reviewers: run the ones the diff calls for without
stopping to ask. Never assume a given agent, plugin, or skill exists; use what your client lists as
available, in this order:

1. **Repo-provided machinery** (reviewer agents, a review command, a review skill). Its dispatch
   rules (security-sensitive paths, extra specialists, domain checks, report add-ons) override
   these defaults.
2. **General-purpose reviewers your client offers**, selected by what the diff touches: tests,
   error handling, type design, new doc comments, security-sensitive paths.
3. **Yourself**, for whatever the first two did not cover. Absent machinery never skips the review.

- You write the single report. Delegate for findings, not for the write-up, unless the repo
  defines its own report format.
- Never dispatch anything that edits code; this review is read-only.
- Brief every reviewer with the ticket context, the exact changed-file list, and "stay in ticket
  scope; out-of-scope observations go under Scope creep", so none re-derive the diff and drift.
- **Repository guidance**: read applicable agent instruction and rules files, focusing on sections
  relevant to the touched areas.

## 4. Verify before reporting

For each candidate finding, read the actual source and confirm: the cited line at the reviewed
revision contains the code the finding names (not a hunk header or counted offset); the flagged
code is really a problem; it isn't already addressed elsewhere in the diff; acceptance-criteria
claims match the actual ticket text. Correct or drop anything that doesn't hold up.

The cited `file:line` must be a line the PR changes, so it can anchor an inline review comment.
When the defect manifests in code the PR doesn't touch, cite the causal changed line (the call
site, signature, or removed guard that makes the untouched code wrong) and name the untouched
location in the finding text. If no causal in-diff line exists, the problem is pre-existing:
report it under Scope creep, not as a finding.

You assign the final P-labels in this pass — specialist agents' severities are input, not binding.
The label is the decision it drives: **P1** you'd block the merge over it · **P2** fix warranted,
wouldn't block · **P3** worth mentioning, wouldn't insist.
Challenge each label against the rubric, in either direction: promote what a specialist undersold,
demote a P1 that wouldn't actually block the merge, and drop a P3 you wouldn't genuinely raise
with a colleague — it never becomes a finding.

Two tests make a label falsifiable before you print it:

- **A P1 must name a change to the reviewed diff.** If the fix is a process action (enforce a
  ticket, gate a release, have someone check production data), it is not a ranked finding: put it
  under its own `### Deploy gate` heading and leave it out of the numbered list. A deferral you
  called defensible cannot also be a blocker.
- **A clean branch is a valid result.** Never promote a finding to fill a severity tier; the length
  of the findings list is not evidence of review effort.

When a label is challenged after the report is printed, re-derive it from the rubric, not from the
tone of the challenge. Say which happened: "re-derivation lands the same, here is why", or "this
was wrong when I wrote it, here is the inconsistency".

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
    ### Deploy gate            <- release preconditions, not diff defects; unnumbered
    ### Acceptance criteria    <- unmet or partially-met only, with evidence
    ### Scope creep
    ### Checked clean          <- risk areas inspected and found sound; one line each
    ### Not verified           <- every check that couldn't run, and what blocked it
    ### Verdict
    ship | needs fixes | blocked

`Checked clean` names the risk areas this diff puts in play that you read and found sound (auth
path, money math, migration ordering), one line each with the evidence, so a quiet review is
distinguishable from an absent one. Only what you actually inspected, and only what the diff
implicates: never pad it.

Missing optional context does not prevent `ship`; list it under `Not verified`. A `Deploy gate`
entry does not prevent `ship` either: the verdict is about the branch, and a release precondition
is not a defect in it. Never report `ship` when a validation required for the changed code could
not run or the reviewed scope could not be established: an audit that did not happen must not read
as one that passed.

## Constraints

- Read-only: never modify files.
- Specialist agents report to you in full; compression happens on the way out. Never drop a
  finding, caveat, or failing check to hit a budget.
