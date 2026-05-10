---
name: debug
description: Diagnose and fix something broken. Asks before applying. Works inside or outside a PSD project.
argument-hint: "<symptom in plain English>"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Task
  - AskUserQuestion
---

<objective>
Investigate a reported problem (an error, a regression, wrong behavior) and propose the minimum fix. Always asks for confirmation before applying — safe for non-technical users.

Orchestrator role: dispatch `debugger` with the user's symptom; surface its diagnosis + fix-applied status. Works in any directory; doesn't require `.planning/`.
</objective>

<execution_context>
@$HOME/.claude/workflows/debug.md
</execution_context>

<process>
1. **No hard pre-flight gates.** Debug is the safety net — it should run even when the project is in an inconsistent state. (Working tree may be dirty; that's expected.)

2. **Companion check (suggestion mode):** scan the available-skills list. If `superpowers:systematic-debugging` is listed, print this single line **before** dispatching:

   > FYI: `superpowers:systematic-debugging` is also available — stronger scientific-method discipline. Abort and run it directly for tough bugs; otherwise continuing with `debug`.

   If not listed, skip silently.

3. **Dispatch `debugger`** with `$ARGUMENTS` as the symptom (verbatim free text). If `$ARGUMENTS` is empty, ask the user for a one-line description first via AskUserQuestion.

4. **Report** the debugger's ≤200-word summary verbatim.

Preserve all gates: never apply a fix without user "Yes apply" confirmation; never advance phase state; never push or amend; never auto-delegate to companion (suggestion only).
</process>
