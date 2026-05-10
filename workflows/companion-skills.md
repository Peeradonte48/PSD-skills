# Companion skills — suggestion-mode delegation map

PSD skills detect when a known-good alternative is available in the user's Claude Code environment and surface it as a suggestion. **Never auto-delegate** — the user always chooses.

This document is the canonical map. Each PSD skill that has companions lists them here. The orchestrator skill (SKILL.md) does the detection and prints a one-line FYI before dispatching its own subagent.

## Detection

The orchestrator scans the available-skills list (provided in the system reminder at session start). If a companion's exact skill name appears in the list, the FYI line fires. Otherwise: silent.

## Map

| PSD skill | Companion | Surface condition | Prefer companion when... | Prefer PSD when... |
|---|---|---|---|---|
| `/psd:brainstorm` | `superpowers:brainstorming` | always | More rigorous exploration of intent; user has a foggy idea and wants depth | Lean ideation, want a structured BRAINSTORM.md ready for `/psd:init` |
| `/psd:debug` | `superpowers:systematic-debugging` | always | Tough bug, scientific-method discipline matters; willing to spend more tokens | Quick targeted fix; want plain-English propose-then-confirm flow |
| `/psd:add-tests` | `superpowers:test-driven-development` | always | Building a new feature test-first; want full TDD discipline | Adding tests retroactively from a passing VERIFICATION.md |
| `/psd:review` | `code-review:code-review` | A PR exists for this branch | You're reviewing the PR in GitHub-context | Local diff-scoped review before opening a PR |
| `/psd:execute` | `superpowers:using-git-worktrees` | Phase has multiple waves OR touches risky paths (auth/payments/migrations) | Want isolation from main branch; comparing variants | Standard in-branch execution |
| `/psd:discuss [N]` (AI) | `gsd-ai-integration-phase` | Phase goal/Stack mentions AI/LLM/agent/embedding/RAG | AI-critical phase needing eval rigor + monitoring contract | Lightweight AI-SPEC.md alongside CONTEXT.md |
| `/psd:discuss [N]` (UI) | `gsd-ui-phase` | Phase goal mentions page/screen/layout/design/UX | Design-heavy phase needing thorough design contract | Lightweight UI-SPEC.md alongside CONTEXT.md |
| `/psd:plan [N]` (AI) | `gsd-ai-integration-phase` | Same AI condition as discuss | Run before `/psd:plan` to lock down the AI-SPEC | Lean phase plan |
| `/psd:plan [N]` (UI) | `gsd-ui-phase` | Same UI condition as discuss | Run before `/psd:plan` to lock down the UI-SPEC | Lean phase plan |
| `/psd:init` | `gsd-new-project` | always | Want extensive parallel-research project bootstrap | Lean, batteries-included defaults; ready to ship Phase 1 fast |
| `/psd:doctor` | `vercel:bootstrap` | Stack mentions Vercel AND `.vercel/project.json` absent | First-time Vercel + linked-resource setup with Marketplace integrations | Manual `vercel link` + per-service env walkthrough |
| `/psd:doctor` | `vercel:env` | Vercel linked AND `.env.local` exists | Direct Vercel env management (pull/push/diff) | PSD's guided per-service walkthrough |
| `/psd:doctor` | `vercel:status` | Vercel linked | Quick state check (deployments, domains, env) | PSD's verbose per-tool check |
| `/psd:doctor` | `supabase:supabase` | Stack mentions Supabase | Direct Supabase MCP for migrations, RLS, edge functions | PSD's guided link + service-role-key walkthrough |
| `/psd:deploy` | `vercel:deploy` | always | Direct Vercel deploy | PSD adds smoke test + DEPLOY.md + AGENTS.md update |
| `/psd:deploy` | `deploy-to-vercel` | when `vercel:deploy` not present | Generic deploy trigger | Same — just a fallback companion |

## Surface format (binding)

When a companion is detected, the orchestrator prints a single line like:

> `FYI: \`<companion>\` is also available — <one-line tradeoff>. Run it directly if you'd prefer; otherwise continuing with \`<psd:skill>\`.`

The line is informational only. The PSD skill continues to its normal subagent dispatch immediately after — no AskUserQuestion, no pause. The user can `Ctrl+C` if they want to switch.

## Hard rules

- **Never auto-delegate.** The user must explicitly run the companion skill themselves if they want it.
- **No artifact translation.** PSD does not adapt a companion's output back into PSD's artifact shape. If the user runs the companion, PSD's pipeline starts fresh on their next `/psd-*` invocation.
- **One line max per detection.** No verbose explanations. The map above is the reference if the user wants more.
- **Skip silently** when no companion is detected. Don't say "no companion available."
- **Don't fight the user.** If they pick PSD's version after seeing the FYI, that's the answer; don't re-suggest.

## Why suggestion mode (not delegation)

- **Token efficiency.** Companions are usually heavier; auto-delegation would betray PSD's "less than GSD" promise.
- **Artifact integrity.** PSD's pipeline depends on specific file shapes (BRAINSTORM.md / CONTEXT.md / PLAN.md / etc.). Adapting companion output back into those shapes is fragile.
- **User control.** Non-technical users benefit from seeing the option but shouldn't be forced into a different mental model mid-flow.
- **Maintenance.** As Claude's skill ecosystem evolves, this map is the only thing to update — no integration code to break.
