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
  criteria. Otherwise proceed and name the gap in the verdict's coverage clause.
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
- Brief every reviewer with the intent, the exact changed-file list, and "stay in scope;
  out-of-scope observations go under Scope creep", so none re-derive the diff and drift.
- **Repository guidance**: read applicable agent instruction and rules files, focusing on sections
  relevant to the touched areas.

## 4. Verify before reporting

For each candidate finding, read the actual source and confirm: the cited line at the reviewed
revision contains the code the finding names (not a hunk header or counted offset); the flagged
code is really a problem; it isn't already addressed elsewhere in the diff; acceptance-criteria
claims match the actual work-item text. Correct or drop anything that doesn't hold up.

The cited `file:line` must be a line the PR changes, so it can anchor an inline review comment.
When the defect manifests in code the PR doesn't touch, cite the causal changed line (the call
site, signature, or removed guard that makes the untouched code wrong) and name the untouched
location in the finding text. If no causal in-diff line exists, the problem is pre-existing:
report it under Scope creep, not as a finding.

You assign the final P-labels in this pass; specialist agents' severities are input, not binding.
The label is the decision it drives: **P1** you'd block the merge over it · **P2** fix warranted,
wouldn't block · **P3** worth mentioning, wouldn't insist.
Challenge each label against the rubric, in either direction: promote what a specialist undersold,
demote a P1 that wouldn't actually block the merge, and drop a P3 you wouldn't genuinely raise
with a colleague; it never becomes a finding.

Two tests make a label falsifiable before you print it:

- **A P1 must name a change to the reviewed diff.** If the fix is a process action (enforce a
  ticket, gate a release, have someone check production data), drop it. A deferral you called
  defensible cannot also be a blocker. Never infer how this project deploys, releases, or
  operates. The rare process action that would genuinely change the merge decision goes in the
  verdict clause, not a section of its own.
- **A clean branch is a valid result.** Never promote a finding to fill a severity tier; the length
  of the findings list is not evidence of review effort.

When a label is challenged after the report is printed, re-derive it from the rubric, not from the
tone of the challenge. Say which happened: "re-derivation lands the same, here is why", or "this
was wrong when I wrote it, here is the inconsistency".

Merge duplicates: when specialists report the same defect, it becomes one line at the label you
judge correct.

Order the final list by severity (all P1s, then P2s, then P3s) and by impact within each
severity. This ranked order is what gets numbered in the report.

## 5. Report

One report, pasteable as-is, per the output contract's `findings.md`. Every line has to earn its
place. Sections with nothing in them are deleted, never kept with "none":

    ## Review: <whatever identifies what you reviewed>
    <1-2 sentences: the vibe>

    ### Findings               <- one numbered flat list in your step-4 rank
    ### Acceptance criteria    <- only a criterion the diff never attempts
    ### Scope creep            <- only changes worth pulling back out
    ### Verdict
    approve | request changes | comment - <coverage clause>

Name what you reviewed with whatever identifiers actually exist: a PR number, a branch, a work
item, or just the scope of the diff. Lead with the PR number when there is one. No fixed slots.

**The vibe.** One or two sentences on the character of the work, not its contents: how it reads
and where the risk sits. Clean, dense, rushed, over-built, mechanical with one real change buried
in it, three unrelated concerns in one diff. Never summarize what the change does, preview the
findings, or state the verdict here. It is a judgment, so it is allowed to be unflattering.

**Acceptance criteria.** An unmet criterion with a line to point at is a finding; put it in the
numbered list and leave this section out. It earns a heading only when the work item asks for
something the diff never attempts, which has no `file:line` to anchor. Never list criteria that
are met.

**Scope creep.** Only what someone might want pulled back out of the branch, or a pre-existing
problem with no causal in-diff line. A stray rename or a reformatted import does not earn a line.

**The verdict clause.** One clause naming the risk areas this diff puts in play that you read and
found sound, then anything a required check could not establish and what blocked it. Only what you
actually inspected, and only what the diff implicates: never pad it, and never invent a risk area
to sound thorough. Per-item evidence stays available on request rather than printed. Never emit a
bare verdict with no coverage clause.

    approve - checked the destructive branch and the dry-run guard; test suite not run (no Docker here).

Missing optional context does not prevent `approve`; name it in the coverage clause. Never report
`approve` when a validation required for the changed code could not run or the reviewed scope
could not be established: an audit that did not happen must not read as one that passed. Report
`comment` instead.

When posting this as a PR review rather than handing it over, drop the `### Verdict` heading and
its value, since the `gh pr review` flag carries the verdict; the coverage clause stays.

## Constraints

- Read-only: never modify files.
- Specialist agents report to you in full; compression happens on the way out. Never drop a
  finding, caveat, or failing check to hit a budget.
