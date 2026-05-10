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
Initialize a new PSD project in the current directory. Gathers project basics (name, problem, requirements, out-of-scope), then **selects a tech stack** appropriate for a non-technical user (detects existing codebase, or recommends a batteries-included default like Next.js+Vercel+Supabase). Dispatches `initializer` to write the four `.planning/` files including the Stack section in PROJECT.md.

Orchestrator role: gate against existing `.planning/`, gather inputs via AskUserQuestion, dispatch the subagent, summarize result. Stack selection itself happens inside the subagent (it's adaptive — only asks what's not already known from BRAINSTORM.md or the existing codebase).
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

3. **Gather inputs** with a single AskUserQuestion call covering: project name, problem statement, top 3 requirements, out-of-scope items.

4. **Dispatch `initializer`** with only the gathered answers + cwd. Do not paste workflow contents into the prompt — reference @$HOME/.claude/workflows/init.md.

5. **Report** the subagent's ≤200-word summary verbatim, then suggest `/psd:plan 1`.

Preserve all gates: never overwrite `.planning/`, never silently `git init`, never fabricate inputs, never auto-delegate to companion (suggestion only).
</process>
