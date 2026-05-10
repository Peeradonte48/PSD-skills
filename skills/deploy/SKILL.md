---
name: deploy
description: Push to a live URL (preview or production). Smoke-tests the URL, records DEPLOY.md, updates AGENTS.md "Where to look". Closes the loop from /psd:ship to "I can show this to a friend."
argument-hint: "[--prod] [--phase N]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Task
---

<objective>
Push the current project to a live URL. Default is preview deploy from current commit. `--prod` deploys to production (requires clean working tree). Records the deploy URL in `.planning/DEPLOY.md` and updates `AGENTS.md` "Where to look" so any teammate can find the live link.

Orchestrator role: validate env (via DOCTOR.md), surface companion skills, dispatch `deployer`. Deploy logic + smoke test happens in the subagent.
</objective>

<execution_context>
@$HOME/.claude/workflows/deploy.md
</execution_context>

<process>
1. **Pre-flight gates** (per workflows/deploy.md):
   - `.planning/DOCTOR.md` must exist with `Verdict: READY` AND timestamp <24h old. Else: print "Env not ready — run `/psd:doctor` first." and exit.
   - For `--prod`: working tree must be clean. Else: print which files are dirty and tell user to commit/stash.

2. **Companion check (suggestion mode):** if `vercel:deploy` is in the available-skills list, print:

   > FYI: `vercel:deploy` is also available — direct Vercel deploy. Continuing with `deploy` (which orchestrates around it for smoke-testing and recording).

   The deployer subagent will use `vercel:deploy` as its first-choice deploy mechanism if installed.

3. **Determine target:**
   - `--prod` flag → production deploy
   - else → preview deploy (default)

4. **Dispatch `deployer`** with `target` (`preview`/`production`) and `phase` (from `--phase N` if passed, else `none`).

5. **Report** the deployer's ≤200-word summary verbatim. Surface the URL prominently so the user can click it.

Preserve all gates: never deploy with dirty working tree on `--prod`; never auto-promote preview to production; never write deploy URLs to AGENTS.md's auto-block; smoke test is read-only curl only.
</process>
