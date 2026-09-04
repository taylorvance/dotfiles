---
name: implement
description: "Implement a feature or fix a bug end-to-end from a work item (tracker issue, in-repo TODO, or plain description): understand, spec-check, plan, implement test-first, validate, commit"
---

Implement a work item end-to-end: understand it, plan and get approval, prove bugs with a
failing test before fixing them, validate with the repo's own machinery, commit, and stop.

## 1. Understand the work item

Resolve the argument to a spec. Infer what kind of reference it is from context. It will not always be a tracker item; personal repos often have none.

- **Tracker reference** (a Jira key, a bare issue number, `#N`, a URL): infer the tracker and any
  missing pieces (like a Jira project prefix) from the repo's remotes, branch names, recent
  commits, and standing guidance. Fetch it with whatever tooling the client provides (Atlassian
  tools, `gh issue view <n> --comments`); read the description, acceptance criteria, and
  sub-tasks; fetch comments for discussion context; if it references a parent epic or linked
  pages, fetch those for the broader goal.
- **In-repo reference**: a feature, TODO, or roadmap entry already documented in the repo; find
  and read it.
- **Prose description**: that is the spec. Restate the requirements in a line or two so a wrong
  reading surfaces before any code is written.
- **No argument**: extract a reference from the current branch name; otherwise ask what to
  implement.
- A reference you cannot fetch or find stops the work: ask instead of inventing a spec from the
  identifier alone.

Classify the work: bug fix, feature, refactor, or chore. The bug path changes the implementation
order in step 4.

**Spec-check before coding.** Verify the item against governing docs and repo reality: acceptance
criteria can be vague, stale, or wrong. A conflict between the spec and the code is a question for
the user, never a silent judgment call. Raise it before implementing, not in the final report.

## 2. Research

- Identify the affected packages, services, and files; read the existing code there for patterns
  and conventions before writing any.
- Read the repo's agent guidance for the touched areas (CLAUDE.md, AGENTS.md, rules files). Its
  domain rules override this skill's defaults.
- Use repo-provided research machinery where it exists (research agents, domain skills).

## 3. Plan

- Always present the plan and wait for approval before writing code, however small the change:
  the plan is also what orients the user to the work item. Use plan mode when the client has one.
- Open with orientation: one or two lines on what the issue is and why it matters, plus the
  step-1 classification.
- For a bug, include the manual repro steps (exact commands, URL, inputs, expected vs actual) so
  the user can confirm the breakage themselves before work starts.
- Then the implementation outline: files to create or modify in order, key design decisions,
  testing approach, and any migration needs.
- Never resolve a step-1 spec conflict silently inside the plan.

## 4. Implement

- **Branching**: follow standing and repo guidance; some repos want a `tv/KEY-description` branch off
  the default branch, others commit straight to it. With no guidance, branch when the change will
  need review, and name the branch from the work item.
- **Bug fix: prove it before fixing it.** Predict the exact wrong value or behavior, then write a
  test on unmodified code asserting the _correct_ value sourced from the spec, never from what the
  code currently does. Run it and check the failure reason: if it fails differently than
  predicted, your model of the bug is wrong; re-investigate instead of proceeding. Then fix, rerun
  green, and keep the test as the regression test. If the repo has its own proof or verification
  skill, load it; its rules take precedence.
- **Feature**: write tests for the new code paths per repo norms, with real dependencies where the
  repo mandates them.
- **Stay in scope.** Never fold adjacent problems silently into the change or file tickets for
  them unasked; collect them for the step-6 report, where the user decides what to take on now.
- Update documentation, help output, and agent guidance made stale by the change.

## 5. Validate

Use the repo's own validation machinery when present: a validate command or skill, a make target,
or a CI-mirroring script. Otherwise discover the pipeline from package.json, the Makefile, or CI
config, and run what applies to the touched code: lint, typecheck, build, test. Fix failures and
rerun until clean; report anything that cannot run.

## 6. Commit and report

- Commit per repo convention, referencing the work item key or issue number when one exists.
- Stop after committing. Never push or open a PR unless explicitly asked; offer it as the next
  step instead.
- Load the `terse` skill (if your harness has no skill loader, read `../terse/SKILL.md`
  relative to this skill's directory) and report tersely: what was done, decisions made,
  and anything remaining or not verified.
- Present the adjacent problems collected in step 4 as a numbered list, ordered by how strongly
  you would take each on now, and ask which to handle; the numbers let the user answer by
  reference.
- End with how to verify: for a bug, the repro steps from the plan, now expected to pass; for a
  feature, the steps to see the new behavior working. Omit for refactors and chores, where the
  validation run is the evidence.
- Add a two-or-three-line reviewer's map: which file to read first, where the core change is,
  which parts are mechanical, and where extra scrutiny is warranted.
