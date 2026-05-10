---
name: resume
description: Read-only — report where you left off and suggest the next skill. Safe to run any time.
argument-hint: ""
allowed-tools:
  - Read
  - Bash
  - Task
---

<objective>
Restore session context after a context reset, new session, or interruption. Reads STATE.md + CHECKPOINT.md + ONE active artifact (not the whole phase tree) and reports the user's position with a suggested next skill.

Orchestrator role: short-circuit trivial cases, dispatch `resumer` only when needed, surface its summary verbatim.
</objective>

<execution_context>
@$HOME/.claude/workflows/resume.md
</execution_context>

<process>
1. **Skip-paths** (no subagent dispatched):
   - If `.planning/` doesn't exist → print one-line: "No PSD project here. Run `/psd:init` to start one." Done.
   - If `.planning/STATE.md` doesn't exist → print: "PSD initialized but STATE.md missing. Did `/psd:init` complete?" Done.

2. **Otherwise dispatch `resumer`**. The agent reads STATE/CHECKPOINT/active-artifact and reports.

3. **Report** the resumer's structured ≤200-word summary verbatim.

Preserve all gates: this skill MUST be read-only — never let the resumer write files, never auto-execute the suggested next skill.
</process>
