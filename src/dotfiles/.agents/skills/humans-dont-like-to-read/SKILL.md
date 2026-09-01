---
name: humans-dont-like-to-read
description: "Any repo: cut any output (review, summary, work item, PR body, answer) to the shortest form that loses nothing"
---

Every line shown to a reader costs them time. Every output (reviews, summaries, work items, PR
descriptions, chat answers) ships in the shortest form that keeps every decision-changing fact.
This governs the output, not the work: think as hard as the task deserves, then report tersely.

If a report already exists above in the session, rewrite it under these rules and print only the
rewrite. Otherwise do the task and apply them to every report for the rest of the session.

**Compress wording, never substance.** Never cut: a finding or its `file:line`; the verdict;
anything blocked, unverified, or assumed; what failed or was skipped, and why; exact numbers,
error strings, and commands the reader will copy. A fact that only survives in a longer form
keeps the longer form. Over budget with facts still uncut? Ship it over budget.

## When the output contains findings

    1. P1 `file:line` — what's wrong → what it breaks. Fix: <the change>.

e.g. 1. P1 `pool.ts:88` — takeout applied twice → payouts 2% low on any funded pool. Fix: drop the second `applyTakeout`.

- Severity leads the line: **P1** worst · **P3** least. The assignment rubric belongs to whoever
  produced the findings (for reviews, the `review` skill).
- ~20 words after the path. Needs more → it's two findings, or you don't understand it yet.
- One physical line per finding: never hard-wrap or indent continuation text; the display wraps it.
- Basename only, unless two changed files share one.
- Impact is a consequence ("payouts 2% low"), not a restatement ("takeout is wrong").
- Fix is the change ("drop the second `applyTakeout`"), not a direction ("review the takeout logic").
- No lead-in ("I noticed"), no hedge ("may", "consider"). Unverified findings say `unverified:` and stay.
- One numbered flat list (`1.`), no severity headings. The number is the priority rank — the
  ordering itself comes from whoever produced the findings.

## Budgets

| Output | Budget |
| --- | --- |
| Review / report | 1 line per finding + 1 verdict line |
| PR description | `## Not fixed` (first, or absent) → `## What changed` → `## Review`; one line per item; GitHub already renders the diff and file list — don't retype either |
| PR review comment | finding lines only — no "overall looks good", no restating the diff |
| Factual question | ≤ 3 lines |
| "Did it work?" | first word yes / no / blocked, then the evidence in one line |
| Implementation report | 1 line per file changed + 1 on verification + 1 on what's left (omit if nothing) |
| Summary (doc, thread, investigation) | takeaway first, then one line per decision-changing fact; no chronology of how you read it |
| Work item / ticket body | problem → evidence → expected vs actual, one line each; never restate what a linked diff or PR shows |
| Anything else | shortest form that keeps every decision-changing fact |

## Everything else

- **Raw markdown, copyable.** A report destined to be pasted elsewhere (review report, PR
  description, PR comment, Jira comment) is emitted as one fenced code block of raw markdown
  syntax — literal `##`, backticks, and bullets the user can copy verbatim, not rendered output.
- Answer first: no preamble, no postamble, no process narration, no self-assessment.
- One structure per answer; say each fact once; code blocks only for copyable content.
- Empty sections are deleted, never kept as "none".
- Never compress inside a quote, test output, error message, or command.
- Never compress by generalizing — "several money-path issues" instead of three findings with paths is a loss.
