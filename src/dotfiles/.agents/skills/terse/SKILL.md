---
name: terse
description: "Any repo: humans don't like to read. Cut any output (review, summary, work item, PR body, chat answer) to the shortest form that loses no decision-changing fact."
---

Every line shown to a reader costs them time. Every output (reviews, summaries, work items, PR
descriptions, chat answers) ships in the shortest form that keeps every decision-changing fact.
This governs the output, not the work: think as hard as the task deserves, then report tersely.

Invoking this does two things:

1. **Rewrite backward.** If a report already exists above in the session, rewrite it under these
   rules and print only the rewrite.
2. **Hold the contract forward.** Apply these formats to every output for the rest of the session.

Where the harness already enforces a concise output style, plain brevity is handled. What this
skill adds is the retroactive rewrite and the named formats below, so lean on those rather than
restating "be brief".

**Compress wording, never substance.** Never cut: a finding or its `file:line`; the verdict;
anything blocked, unverified, or assumed; what failed or was skipped, and why; exact numbers,
error strings, and commands the reader will copy. A fact that only survives in a longer form
keeps the longer form. Over budget with facts still uncut? Ship it over budget.

## Findings

Output that carries ranked findings (code review, audit, triage) follows `findings.md` in this
skill's directory: read it when the output has findings, skip it otherwise.

## Budgets

| Output | Budget |
| --- | --- |
| Review / report | 1-2 sentences on the character of the work + 1 line per finding + 1 verdict line |
| PR description | `## Not fixed` (first, or absent) → `## What changed` → `## Review`; one line per item; GitHub already renders the diff and file list, so don't retype either |
| PR review comment | finding lines only: no "overall looks good", no restating the diff |
| Factual question | ≤ 3 lines |
| "Did it work?" | first word yes / no / blocked, then the evidence in one line |
| Implementation report | 1 line per file changed + 1 on verification + 1 on what's left (omit if nothing) |
| Summary (doc, thread, investigation) | takeaway first, then one line per decision-changing fact; no chronology of how you read it |
| Work item / ticket body | problem → evidence → expected vs actual, one line each; never restate what a linked diff or PR shows |
| Decision log entry | ≤ 2 sentences per template field; the decision reached, never the deliberation that reached it. One reason under `Rationale`: the one that would change a future maintainer's mind. Drop a field rather than pad it |
| Anything else | shortest form that keeps every decision-changing fact |

## Everything else

- **Raw markdown, copyable.** A report destined to be pasted elsewhere (review report, PR
  description, PR comment, tracker comment) is emitted as one fenced code block of raw markdown
  syntax: literal `##`, backticks, and bullets the user can copy verbatim, not rendered output.
  Ordinary answers are rendered normally.
- Answer first: no preamble, no postamble, no process narration, no self-assessment.
- One structure per answer; say each fact once; code blocks only for copyable content.
- Empty sections are deleted, never kept as "none".
- Never compress inside a quote, test output, error message, or command.
- Never compress by generalizing: "several money-path issues" instead of three findings with
  paths is a loss.
