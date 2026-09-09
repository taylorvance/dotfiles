# Finding lines

The shape of every ranked finding, in any output that carries them (code review, audit, triage).
Loaded from `SKILL.md`; the rules there still apply.

    1. P1 `file:line` - what's wrong → what it breaks. Fix: <the change>.

e.g. 1. P1 `clean:88` - unlink runs before the dry-run check → `-n` deletes files. Fix: move the guard above the loop.

Four constraints hold the line to that shape. Each one names a habit that has reliably doubled
real findings past it:

- **One anchor.** The leading `file:line` is where an inline comment attaches, not the only place
  the line may point. Reference whatever the fix or the real defect needs: cite the causal changed
  line and name the untouched location in the text, or name the sibling the fix should match. A
  second *defect* is a second finding; a second location is not.
- **One `Fix:` clause, and it ends the line.** Nothing follows it. A fix spanning several lines is
  still one finding: the anchor is where the comment lands, and the fix clause names the range.
- **No effort asides.** "(12 of 14 DAOs have one)", "9/9 tests pass", "verified against source":
  an aside that argues the finding is real rather than locating or fixing it is padding.
- **One sentence before `Fix:`.** A semicolon splicing on a second claim is the same violation.
  Needs more → it's two findings, or you don't understand it yet.

Then:

- Severity leads the line: **P1** worst · **P3** least. The assignment rubric belongs to whoever
  produced the findings (for reviews, the `review` skill).
- One physical line per finding: never hard-wrap or indent continuation text; the display wraps it.
- Basename only, unless two changed files share one.
- Impact is a consequence ("`-n` deletes files"), not a restatement ("the guard is misplaced").
- Fix is the change ("move the guard above the loop"), not a direction ("review the dry-run logic").
- No lead-in ("I noticed"), no hedge ("may", "consider"). Unverified findings say `unverified:` and stay.
- One numbered flat list (`1.`), no severity headings. The number is the priority rank; the
  ordering itself comes from whoever produced the findings.
