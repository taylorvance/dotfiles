---
name: review
description: Review a branch, a PR, or a supplied diff before merging: grounded in the work item or the commits, dispatches whatever reviewers the repo and the client provide, verifies every finding, reports one line each
---

Review a diff before merging: ground it in the work item where there is one and the commits where
there is not, use the repo's own review machinery where it exists, verify every finding against
source, report tersely.

Load the `terse` skill now (if your harness has no skill loader, read its SKILL.md from the
sibling directory): it is the output contract, and its `findings.md` defines the finding-line shape.

## 1. Scope the diff

- Default branch: `git default` (dotfiles alias), falling back to
  `git symbolic-ref --short refs/remotes/origin/HEAD`.
- `git diff <default>...HEAD --name-only` for changed files, `git log <default>..HEAD --oneline`
  for commit context. Empty diff → say so and stop.
- If the invocation names a PR number or another branch, review that instead: in a worktree,
  never by switching the checkout.
- If it supplies a diff directly, or points at uncommitted work, review that and skip the branch
  machinery entirely.

## 2. Work item + PR context

- Extract a work-item key (a tracker key like `[A-Z]+-\d+`, or a bare `#N`) from, in order: branch
  name, last commit subject, PR title and body (`gh pr list --head "$(git branch --show-current)"
--json number,title,body,url`).
- If a key is found and a tracker tool is available, fetch the item; capture summary and acceptance
  criteria. Otherwise proceed and name the gap in the line to the requester.
- Many repos have no tracker at all. That is not a gap to report: the diff and its commits are the
  intent, and the report simply omits the key.

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
- Brief every reviewer with the intent, the exact changed-file list, the admission gate from
  step 4 verbatim, and "review these files, not the ticket's boundaries: a defect is a defect
  wherever the diff put it, and a sound change outside the ticket is not a finding". A specialist
  that reports 40 candidates has moved the triage to you, and a long list anchors.
- **Repository guidance**: read applicable agent instruction and rules files, focusing on sections
  relevant to the touched areas.

## 4. Verify before reporting

For each candidate finding, read the actual source and confirm: the cited line at the reviewed
revision contains the code the finding names (not a hunk header or counted offset); it isn't
already addressed elsewhere in the diff; acceptance-criteria claims match the actual work-item
text. Correct or drop anything that doesn't hold up.

Then one admission gate, applied to every candidate including every one a specialist handed you.
The bar is high and it is not a budget: an author discounts a reviewer who ships false positives,
and a list that is mostly nits buries the P1 at the top of it. A candidate that fails is
**dropped, never demoted**; a tier is not where weak findings go to live.

Two doors in, and a candidate needs only one:

- **A defect names its failure.** The concrete inputs or state that reach the flagged line, and
  the wrong output, crash, or corrupted record that follows. Cannot write that? It is a
  hypothetical. Say `unverified:` only when you established the mechanism and could not execute
  it, never as a hedge on a mechanism you never established.
- **A fact the author cannot dispute.** A false statement in a comment, an untested route, a value
  that contradicts its own schema, a doc that contradicts the code it documents. No failure
  scenario needed. Preference is not fact: naming, ordering, style, structure you would have
  chosen differently, a rationale clause with no behavioral consequence, and a test that could
  exist are all out at every tier.

The cited `file:line` must be a line the PR changes, so it can anchor an inline review comment.
When the defect manifests in code the PR doesn't touch, cite the causal changed line (the call
site, signature, or removed guard that makes the untouched code wrong) and name the untouched
location in the finding text. If no causal in-diff line exists, the problem is pre-existing: it is
one line to the requester at most, never a finding.

You assign the final P-labels in this pass; specialist agents' severities are input, not binding.
The label is the decision it drives: **P1** you'd block the merge over it · **P2** fix warranted,
wouldn't block · **P3** worth mentioning, wouldn't insist.
Challenge each label against the rubric, in either direction: promote what a specialist undersold,
demote a P1 that wouldn't actually block the merge.

Two tests make a label falsifiable before you print it:

- **A P1 must name a change to the reviewed diff.** If the fix is a process action (enforce a
  ticket, gate a release, have someone check production data), drop it. A deferral you called
  defensible cannot also be a blocker. Never infer how this project deploys, releases, or
  operates. The rare process action that would genuinely change the merge decision goes in the
  line to the requester, not a section of its own.
- **A clean branch is a valid result.** Never promote a finding to fill a severity tier; the length
  of the findings list is not evidence of review effort.

When a label is challenged after the report is printed, re-derive it from the rubric, not from the
tone of the challenge. Say which happened: "re-derivation lands the same, here is why", or "this
was wrong when I wrote it, here is the inconsistency".

Merge duplicates and shared causes: when specialists report the same defect it becomes one line at
the label you judge correct, and when several P3s turn out to share one cause, report the cause at
the tier it earns and drop the instances. Itemizing instances is what makes a list read as nits.

Order the final list by severity (all P1s, then P2s, then P3s) and by impact within each
severity. This ranked order is what gets numbered in the report.

## 5. Report

One report, pasteable as-is, per the output contract's `findings.md`. It carries no section
headings: a title, a verdict-first topline, the ranked findings, and at most one `unverified:`
line.

    ## Review: <whatever identifies what you reviewed>
    <verdict>[: what the ranked list does not already show]

    1. P1 `file:line` - ...    <- one flat numbered list in your step-4 rank
    2. ...

    unverified: <what a required check could not establish>   <- only when it blocks the verdict

Name what you reviewed with whatever identifiers actually exist: a PR number, a branch, a work
item, or just the scope of the diff. Lead with the PR number when there is one. No fixed slots.

**The topline.** The verdict word first: you are writing to the gatekeeper, and four P2s do not
say whether to block. Never count the findings after it, because the P labels below already do
that. Earn the rest of the line or stop at the word, and it is earned only by something the ranked
list does not show: where the risk concentrates, three unrelated concerns in one diff, one real
change buried in a mechanical rename. Never assess the work's character. No "careful",
"well-evidenced", "surgical", "densely argued", and no unflattering mirror of those either: a
judgment aimed at the author of the diff you are reviewing defaults to praise, and praise is the
first thing a reader skips. Never summarize what the change does or preview the findings.

    request changes: every finding is downstream of the queue handoff.

**Nothing else goes in the block.** An unmet acceptance criterion is a finding, cited at the line
that fails it. A criterion the diff never attempts, or a pre-existing problem with no causal
in-diff line: one line each to the requester, and only when the line would change what they do
next. Both were sections once and went unread, because neither is the review.

**Scope creep is not a defect.** A diff doing more than its ticket asked is never a finding, a
note, or a caveat, and never earns a line anywhere. Judge the extra change on its merits like
anything else in the diff: wrong is a finding at the line that is wrong, and fine goes unmentioned.
Never ask whether a good change belonged in this ticket.

**The `unverified:` line.** Only when a validation the changed code needs could not run or the
reviewed scope could not be established: that is why the verdict is not `approve`, so the PR
author needs it too. Never list risk areas you inspected and found sound; that is effort, not a
decision, and per-item evidence stays available on request.

When posting as a PR review rather than handing it over, drop the verdict word from the topline,
since the `gh pr review` flag carries it. Everything else stays as written.

Missing optional context does not prevent `approve`; name it in the line to the requester. Never
report `approve` when a validation required for the changed code could not run or the reviewed
scope could not be established: an audit that did not happen must not read as one that passed.
Report `comment` instead.

## Constraints

- Read-only: never modify files.
- Specialist agents report to you in full; admission and compression are both yours. Findings
  drop at step 4, for failing an admission test. Never drop one at write-up time to hit a length
  budget, and never drop a caveat or a failing check at all.
