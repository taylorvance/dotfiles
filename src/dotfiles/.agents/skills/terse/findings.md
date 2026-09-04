# Finding lines

The shape of every ranked finding, in any output that carries them (code review, audit, triage).
Loaded from `SKILL.md`; the rules there still apply.

    1. P1 `file:line` - what's wrong → what it breaks. Fix: <the change>.

e.g. 1. P1 `clean:88` - unlink runs before the dry-run check → `-n` deletes files. Fix: move the guard above the loop.

- Severity leads the line: **P1** worst · **P3** least. The assignment rubric belongs to whoever
  produced the findings (for reviews, the `review` skill).
- ~20 words after the path. Needs more → it's two findings, or you don't understand it yet.
- One physical line per finding: never hard-wrap or indent continuation text; the display wraps it.
- Basename only, unless two changed files share one.
- Impact is a consequence ("`-n` deletes files"), not a restatement ("the guard is misplaced").
- Fix is the change ("move the guard above the loop"), not a direction ("review the dry-run logic").
- No lead-in ("I noticed"), no hedge ("may", "consider"). Unverified findings say `unverified:` and stay.
- One numbered flat list (`1.`), no severity headings. The number is the priority rank; the
  ordering itself comes from whoever produced the findings.
