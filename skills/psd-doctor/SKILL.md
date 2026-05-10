---
name: psd-doctor
description: Environment health check + first-time provisioning of cloud projects + .env walkthrough. The bridge from "PROJECT.md says we use Vercel+Supabase" to "everything is actually set up."
argument-hint: "[--force] [--smoke-test]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Task
  - AskUserQuestion
---

<objective>
Run environment health checks, provision Vercel/Supabase project links if missing, walk the user through `.env` setup. Designed for non-technical users — verbose, plain-English, copy-paste install commands. Writes `.planning/DOCTOR.md` so `psd-deploy` can skip its own pre-flight if env is fresh.

Orchestrator role: validate state, surface companion skills, dispatch `psd-doctor` agent. Doctor's heavy lifting (CLI checks, link flows, env walkthrough) happens in the subagent.
</objective>

<execution_context>
@$HOME/.claude/workflows/doctor.md
</execution_context>

<process>
1. **Pre-flight gates** (per workflows/doctor.md):
   - `.planning/PROJECT.md` must exist; else suggest `/psd-init` first.
   - **Skip-path:** if `.planning/DOCTOR.md` exists AND <24h old AND `--force` not passed → print "Env recently checked. Pass --force to re-check." and exit.

2. **Companion check (suggestion mode):** scan the available-skills list. If any of these are listed, print one consolidated FYI line **before** dispatching:

   - `vercel:bootstrap` — preferred for first-time Vercel + linked-resource setup
   - `vercel:env` — env management
   - `vercel:status` — project status check
   - `supabase:supabase` — Supabase ops

   Format: "FYI: companions available — `<list>`. The doctor will use them automatically when they help."

3. **Dispatch `psd-doctor`** with `--force` and `--smoke-test` flags if passed.

4. **Report** the doctor's ≤200-word summary verbatim. If verdict is `READY`, suggest `/psd-deploy`. If `NEEDS-ATTENTION`, list the unresolved items so the user knows what to do next.

Preserve all gates: never write secret values to logs/docs, never auto-push env to Vercel without confirmation, never overwrite `.env*` without confirmation, never auto-delegate to companion (suggestion mode).
</process>
