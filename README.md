# PSD — A Focused GSD-style Skill Suite

A 7-skill workflow toolkit for building and shipping real software with Claude Code. Inspired by [GSD](https://github.com/gsd-build/get-shit-done) but pruned to the minimum viable shipping loop.

## Skills

| Skill | What it does |
|---|---|
| `/psd-brainstorm` | _(optional, pre-init)_ Socratic project ideation → `BRAINSTORM.md` |
| `/psd-init` | Bootstrap a project + **pick a stack** (Next.js+Vercel by default for web; Expo for mobile; etc.). Writes `.planning/PROJECT.md` (with Stack section), `ROADMAP.md`, `STATE.md`. Consumes `BRAINSTORM.md` if present. |
| `/psd-doctor` | Env health check + first-time Vercel/Supabase project link + `.env` walkthrough. Bridges "PROJECT.md says we use Vercel" to "everything is set up." Writes `DOCTOR.md`. |
| `/psd-discuss [N]` | _(optional, pre-plan)_ Adaptive Q&A → `phases/Phase N/CONTEXT.md` |
| `/psd-plan [N]` | Decompose phase N into atomic plans (one commit each); reads `CONTEXT.md` if present |
| `/psd-execute [N]` | Implement every atomic plan in phase N, atomic commits |
| `/psd-verify [N]` | Conversational UAT — walk success criteria, write `VERIFICATION.md` |
| `/psd-ship [N]` | PR + `SUMMARY.md`, advance `STATE.md` to next phase. Auto-extracts ≤5 obstacles into `phases/Phase N/LESSONS.md` + rolling `.planning/LESSONS.md` so the next phase's planner doesn't repeat mistakes. |
| `/psd-deploy [--prod] [--phase N]` | Push to a live URL (preview by default; `--prod` for production). Smoke-tests + records `DEPLOY.md` + updates `AGENTS.md` "Where to look". Closes the loop from PR to "I can show this to a friend." |
| `/psd-review [N]` | Lightweight code review + security + eval audit on the phase's diff. Writes `REVIEW.md` with P0/P1/P2. `psd-ship` blocks on uncleared P0s. |
| `/psd-add-tests [N]` | Generate automated tests from `VERIFICATION.md` PASS criteria. Matches project's existing test framework. Opt-in between verify and ship. |
| `/psd-debug "<symptom>"` | Diagnose & fix a problem (asks before applying). Works inside or outside a PSD project. |
| `/psd-preview [N]` | Read-only plain-English narrative — what you'll be able to do when each phase ships. No args = whole roadmap, `[N]` = single phase. |
| `/psd-resume` | Read-only: report where you left off, suggest next skill |
| `/psd-new-milestone` | Archive current milestone → `milestones/v{N}/`, scaffold next |

Plus an auto-checkpoint hook (`PostToolUse` + `Stop`) that maintains `.planning/CHECKPOINT.md` so `psd-resume` always has a fresh restore point — even after token-limit / API / network errors mid-turn.

## Token efficiency

Every skill is a thin orchestrator (~100 lines) that dispatches a fresh-context subagent for the heavy work. The subagent reads files (not their content) and reports back in ≤200 words. Main session stays under ~5k tokens per phase, vs. 100k+ for naive single-context prompting.

## Model tiers per agent

Each PSD subagent declares the Claude model that fits its work via the `model:` frontmatter field:

| Tier | Model | Agents | Why |
|---|---|---|---|
| **Opus 4.7** (heaviest reasoning) | `opus` | `psd-researcher`, `psd-planner`, `psd-plan-reviewer`, `psd-discusser`, `psd-brainstormer`, `psd-debugger`, `psd-reviewer` | Accuracy-critical: research synthesis, atomic plan decomposition, adversarial review, scientific-method debugging |
| **Sonnet 4.6** (balanced) | `sonnet` | `psd-executor`, `psd-tester`, `psd-initializer`, `psd-shipper`, `psd-milestoner`, `psd-verifier` | Code generation, template filling, mechanical work where Sonnet's speed/cost balance wins |
| **Haiku 4.5** (fast, cheap) | `haiku` | `psd-resumer`, `psd-previewer`, `psd-retrospector` | Pure read-only summarization with no judgement needed (retrospect: mechanical extraction with mandatory source citation) |

This puts the most expensive model where accuracy matters most (research + planning + critique) and uses cheaper models for code generation and trivial summarization. Subagents inherit the tier when dispatched; main-context skills stay on whatever model the user is running.

## Install

```bash
./install.sh
```

This:
1. Symlinks `skills/psd-*/`, `agents/psd-*.md`, `workflows/*.md` into `~/.claude/`
2. Registers `hooks/psd-checkpoint.sh` in `~/.claude/settings.json` under `PostToolUse` (matched to `Write|Edit|Bash|NotebookEdit`) and `Stop`

The hook is a no-op outside `.planning/`-bearing repos, so it's safe to leave globally enabled.

## Uninstall

```bash
./uninstall.sh
```

Removes the symlinks and surgically deletes the hook entries from `~/.claude/settings.json` (leaves your other hooks intact).

## Workflow — from idea to live URL

```
/psd-brainstorm "<idea>"     # optional: Socratic ideation, writes BRAINSTORM.md
/psd-init                    # one-time: picks a stack + creates .planning/ (consumes BRAINSTORM.md)
/psd-doctor                  # one-time per env: link Vercel/Supabase, walk through .env, writes DOCTOR.md
/psd-discuss 1               # optional: clarify Phase 1, writes CONTEXT.md
/psd-plan 1                  # plan first phase (reads CONTEXT.md if present)
/psd-execute 1               # build it
/psd-verify 1                # UAT
/psd-review 1                # OPTIONAL: code review + security + eval audit
/psd-add-tests 1             # OPTIONAL: generate regression tests from VERIFICATION.md
/psd-ship 1                  # PR + advance (blocks on uncleared P0 findings)
/psd-deploy                  # push to live preview URL, smoke test, record DEPLOY.md
/psd-deploy --prod           # after PR merge: push to production
/psd-discuss 2 ...           # optional per-phase clarification, repeat
/psd-new-milestone           # close v1, open v2
/psd-resume                  # any time, in a new session

# whenever something breaks:
/psd-debug "the page is blank when I click submit"
```

### From PR to live URL (the "vibe coding ships real product" path)

The two skills that close the gap between "PSD opened a PR" and "my friends can use the app":

1. **`/psd-doctor`** — one-time-per-env setup. Verifies `node`/`vercel`/`gh`/`jq` are installed and logged in. Runs `vercel link` if the Vercel project isn't linked yet; same for Supabase. Walks through every API key your stack needs (Anthropic, Stripe, Resend, etc.) with dashboard links, writes them to `.env.local`, and offers to sync to Vercel. Writes `DOCTOR.md` with the env state so subsequent `/psd-deploy` calls skip re-checking when env is fresh.

2. **`/psd-deploy`** — push the project to a live URL. By default does a preview deploy from your current commit (matches the PR-driven flow). Pass `--prod` after the PR merges to push to production. Both run a smoke test (does the URL return 200?) and record everything to `DEPLOY.md` + update `AGENTS.md` "Where to look" so any teammate sees the live link without asking.

Both are thin orchestrators that **delegate to companion skills** (`vercel:deploy`, `vercel:bootstrap`, `vercel:env`, `supabase:supabase`) when they're installed in your Claude Code environment, and fall back to direct CLI commands otherwise. The user always stays in control — companions are surfaced as "FYI" suggestions, never auto-invoked.

`brainstorm` and `discuss` cap themselves at 7 adaptive questions each. `debug` is the safety net — it asks for confirmation before applying any fix, and works even when `.planning/` doesn't exist.

### `/psd-plan` defaults — accuracy first

PSD is opinionated toward accurate research and planning, since errors here cascade to every downstream phase. **Research, plan-checker, and peer-review are all ON by default.** Flags exist to opt out when you want speed:

- `--no-research` — skip research even if it would auto-fire (lean mode for trivial phases)
- `--no-peer-review` — skip the adversarial `psd-plan-reviewer`
- `--research` — force re-research even if `RESEARCH.md` exists
- `--deep` — raise research caps (8 fetches/target, 700-line cap; default is 5/500)
- `--from-failure` — re-plan only the deltas from `VERIFICATION.md` failures (skips research and peer-review unless explicitly flagged)

The **plan-checker** runs always — it's deterministic (no LLM cost). It enforces:
- Every PLAN.md success criterion is covered by at least one plan
- No two plans in the same wave touch the same file
- Every plan's test criteria is specific (not "works correctly" or "no errors")
- Plan IDs are sequential and well-formed
- All `depends_on` references are valid

The planner self-corrects fixable issues; surfaces the rest to the user before completing.

### Auto-detected AI/UI phase contracts
`/psd-discuss` detects when a phase is AI-heavy (Stack mentions AI SDK / LLM, or goal mentions agent/chat/embedding) or UI-heavy (goal mentions page/screen/layout/form, or Stack has a frontend framework). When detected, the discusser asks 3-5 extra adaptive questions and writes a lightweight `AI-SPEC.md` and/or `UI-SPEC.md` alongside `CONTEXT.md`. The planner and reviewer treat these as binding contracts.

### Preview gates (automatic, for fuzzy users)

`psd-init` and `psd-plan` automatically show a plain-English preview at the end and require approval before completing. If the user says "this isn't right," they loop back to revise (max 2 rounds, then a forced ship-or-abort choice). This means a non-technical user can't accidentally proceed past a roadmap or plan they don't actually agree with.

`/psd-preview [N]` is the read-only, on-demand version of the same narrative — useful when you've stepped away and want to remind yourself what's coming, or when showing a teammate "here's what we're building" without making them read jargon-heavy plan files.

### Default stack picks (during `/psd-init`)
For non-technical users, `psd-init` recommends batteries-included defaults so deployment isn't a science project:

| App type | Default recommendation |
|---|---|
| Web app + DB + auth | Next.js 16 + Tailwind + shadcn/ui + Vercel + Supabase |
| Web app, static | Next.js + Tailwind + Vercel |
| Mobile app | Expo (React Native) + TypeScript |
| CLI / script | Node + TypeScript |
| API only | Hono on Vercel Functions |

The init agent detects an existing codebase if any (and confirms rather than re-picks). It asks at most 3 questions to choose a stack.

## File layout in your project

```
.planning/
├── PROJECT.md          # vision, requirements
├── ROADMAP.md          # current milestone's phases
├── STATE.md            # current phase pointer (skill-maintained)
├── CHECKPOINT.md       # rolling per-turn snapshot (hook-maintained, ≤30 entries)
├── milestones/
│   └── v1/             # archived after psd-new-milestone
└── phases/
    └── Phase 1/
        ├── PLAN.md
        ├── plans/1-01.md, 1-02.md, ...
        ├── VERIFICATION.md
        └── SUMMARY.md
```

## Team collaboration & cross-AI handoff

PSD is designed so a teammate without PSD installed — or an AI that isn't Claude Code (Codex, Cursor, etc.) — can still pick up the work.

`psd-init` scaffolds four root-level files in any project it bootstraps:

| File | What it's for |
|---|---|
| `AGENTS.md` | The cross-AI starting point. Project context + stack + conventions + a "Resume without PSD" protocol + a `<!-- AUTO:CURRENT_STATE -->` block that the checkpoint hook keeps fresh on every turn. |
| `CLAUDE.md` | Tiny stub pointing back to `AGENTS.md` so Claude Code's `CLAUDE.md` convention still resolves. |
| `.github/pull_request_template.md` | Structured PR shape used by `psd-ship` and by any teammate opening a PR by hand. |
| `.gitattributes` | Adds `AGENTS.md merge=union` so the auto-updated block doesn't conflict on multi-author branches. |

### What this means for a teammate or bare AI

If someone clones the repo without PSD installed, they read `AGENTS.md` and find:
1. What the project is and the stack it uses
2. The conventions (atomic commits, phase structure, no `git add -A`)
3. The current state — milestone, active phase, last skill run, last commit, recent activity (auto-updated)
4. A 6-step "Resume without PSD" protocol they (or any AI) can follow to commit the next atomic plan without `psd-execute`

### What this means for `psd-ship`

When the shipper opens a PR, it fills in `.github/pull_request_template.md` with the phase, plans, verification result, and links — so reviewers see a clean structured PR even if they've never heard of PSD.

### What this means for the hook

The same `PostToolUse`/`Stop` hook that maintains `.planning/CHECKPOINT.md` also rewrites the `AGENTS.md` auto-block on every turn. It's a no-op outside `.planning/` repos, and skips silently if `AGENTS.md` doesn't have the sentinel markers. So the hook:
- Survives mid-turn API errors (fires after every successful mutating tool call)
- Keeps `AGENTS.md` fresh for the next collaborator without any skill running
- Doesn't depend on Claude Code itself — it's just a bash script

## Requirements

- Claude Code
- `jq` (for safe `~/.claude/settings.json` edits in install.sh; also used by the hook)
- `git` (recommended; checkpoint hook degrades gracefully without it)
- `gh` CLI (only needed by `psd-ship` to open PRs; not required for the rest)
