# Workflow: deploy

Push to a live URL. Closes the loop from `/psd:ship` (which only opens a PR) to "I can show this to a friend."

Thin orchestrator: delegates to `vercel:deploy` companion when present, else `deploy-to-vercel`, else direct `vercel deploy` bash.

## When to run
- Auto-suggested by `ship` in its "Quality gates this phase" block
- After PR merge to push production deploy (`--prod`)
- For first-time deploy of a new project (uses `doctor` if env not ready)

## Pre-flight gates
1. `.planning/DOCTOR.md` exists AND `Verdict: READY` — else direct user to `/psd:doctor` first.
2. Working tree clean for `--prod` deploys; preview deploys allow dirty (Vercel previews from current commit).

## Args

- (no args) — preview deploy from current commit (or current branch via Vercel auto-deploy)
- `--prod` — production deploy. Required: working tree clean, on default branch (main/master) typically.
- `--phase N` — record the deploy URL specifically for Phase N's SUMMARY.md (default: write to top-level DEPLOY.md only)

## Subagent dispatch
Spawn `deployer`:

```
You are deployer.

Inputs:
- target: <"preview" | "production">
- phase: <N | "none">

Read yourself:
- .planning/DOCTOR.md (verify Verdict: READY)
- .planning/STATE.md
- .planning/PROJECT.md (Stack section, especially the Hosting field)
- existing .planning/DEPLOY.md (if it exists, append; else create)

Read @$HOME/.claude/workflows/deploy.md.

Process:
1. Verify pre-flight (DOCTOR.md READY; for --prod, working tree clean)
2. Detect deploy method:
   - vercel:deploy companion present → invoke it
   - deploy-to-vercel companion present → invoke it
   - else: direct `vercel deploy [--prod]` bash
3. Capture the deploy URL from the output
4. Smoke test: curl -fsSL -o /dev/null -w "%{http_code}" <url> (expect 200/3xx)
5. Append to DEPLOY.md per template
6. Update AGENTS.md "Where to look" with the latest live URL (use sentinel-marker pattern; don't disturb the AUTO:CURRENT_STATE block)
7. If --phase N: also append URL to phases/Phase N/SUMMARY.md "PR" field (or new "Deploy" field if SUMMARY exists)
8. Update STATE.md "Recent decisions": "Deployed Phase N <preview|production> <date> — <url>"

Report back in <=200 words: target, URL, smoke-test result, where it's recorded.
```

## Companion delegation (suggestion-mode)

If `vercel:deploy` is in the available-skills list, the orchestrator prints a one-line FYI before dispatching:

> FYI: `vercel:deploy` is also available — direct Vercel deploy. Continuing with `deploy` (which orchestrates around it).

`deployer` itself uses `vercel:deploy` as its first-choice deploy mechanism if installed.

## Smoke test

Default: `curl -fsSL -o /dev/null -w "%{http_code}" <url>`. Expect 200 (or 3xx if root redirects). Anything 4xx/5xx → smoke test fails; report with status code.

This is intentionally light — not a Lighthouse score, not a full E2E. Just "did the server respond?" If users want richer post-deploy checks, they can run `vercel:verification` (companion) or set up monitoring.

## Artifact template

### `.planning/DEPLOY.md`
```markdown
# Deploy log

| Date | Target | URL | Smoke | Phase | Commit |
|---|---|---|---|---|---|
| 2026-05-10T08:30Z | preview | https://app-abc123.vercel.app | 200 ✓ | 2 | 7f3a2b1 |
| 2026-05-10T09:45Z | production | https://app.example.com | 200 ✓ | 2 | 7f3a2b1 |
```

Append-only (newest at top or bottom, consistent — pick newest at bottom for chronological history).

### AGENTS.md "Where to look" update
Find the existing "Where to look" table and add a row (idempotent — replace if "Live deploy" row already exists):
```markdown
| Live deploy (latest) | <preview-url> (preview) / <prod-url> (production) |
```

### `phases/Phase {N}/SUMMARY.md` (if --phase passed)
Add a "Deploy" line under the existing "PR" line:
```markdown
**Deploy:** <preview-url> (preview), <prod-url> (production)
```

## Hard rules

- **Never deploy with dirty working tree on `--prod`.** Preview is OK; production must be clean.
- **Never auto-promote preview to prod.** `--prod` is explicit.
- **Never push deploy URLs into AGENTS.md's `<!-- AUTO:CURRENT_STATE -->` block** — that's hook-managed; live URLs go in the static "Where to look" section.
- **Never run smoke tests against production with destructive curl** — only `-fsSL -o /dev/null` (read-only fetch).
- **Cap DEPLOY.md at the most recent 50 entries** — older deploys can be archived to `.planning/milestones/v{N}/DEPLOY.md` on milestone close (future enhancement).
- **No DNS / domain config in this skill** — that's `vercel:vercel-cli` territory; surface as a suggestion if the user asks about a custom domain.
