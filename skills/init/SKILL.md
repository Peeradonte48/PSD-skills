---
name: init
description: Bootstrap a new PSD project — creates .planning/PROJECT.md, ROADMAP.md, STATE.md, CHECKPOINT.md.
argument-hint: ""
allowed-tools:
  - Read
  - Write
  - Bash
  - Task
  - AskUserQuestion
---

<objective>
Initialize a new PSD project in the current directory. Dispatches `initializer`, which runs an adaptive Socratic Q&A (3-7 questions, opt-in extension to 12) probing problem statement, top requirements, out-of-scope, and stack — with clarification mode, "I don't know" defaults, and a mid-flow reflect — then writes the four `.planning/` files including the Stack section in PROJECT.md.

Orchestrator role: gate against existing `.planning/`, dispatch the subagent, summarize result. **All interactive gathering lives in the agent**, not here — this keeps the orchestrator thin and the dialogue consistent across the brainstorm/init/discuss trio.
</objective>

<execution_context>
@$HOME/.claude/workflows/init.md
</execution_context>

<process>
1. **Pre-flight gates** (per workflows/init.md):
   - If `.planning/` exists → STOP, suggest `/psd:resume` or `/psd:new-milestone`.
   - If not a git repo → ask user whether to `git init` first.

2. **Companion check (suggestion mode):** scan the available-skills list. If `gsd-new-project` is listed, print:

   > FYI: `gsd-new-project` is also available — deeper project bootstrap with parallel research agents. Run it directly for projects where you want extensive context-gathering; otherwise continuing with `init` (lean, batteries-included defaults).

   If not listed, skip silently.

3. **Dispatch `initializer`** — agent owns all interactive gathering (adaptive Q&A, clarification, "I don't know" defaults, mid-flow reflect, "Keep going?" extension, stack confirmation). Pass only `cwd` and any `revision_feedback` from the auto-preview loop. Do not paste workflow contents into the prompt — reference @$HOME/.claude/workflows/init.md.

4. **Report** the subagent's ≤200-word summary verbatim, then suggest `/psd:doctor` (recommended) or `/psd:plan 1`.

Preserve all gates: never overwrite `.planning/`, never silently `git init`, never fabricate inputs, never auto-delegate to companion (suggestion only), never bypass the agent's reflect step on shallow input, never let the orchestrator gather inputs itself (the agent owns the dialogue).
</process>
