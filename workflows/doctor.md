# Workflow: doctor

Environment health check + first-time provisioning + `.env` walkthrough. The bridge between "PSD wrote `Stack: Next.js + Vercel + Supabase` in PROJECT.md" and "user can actually run/deploy the project."

Designed for non-technical users — verbose, plain-English, walks through each missing piece with copy-paste install commands.

## When to run
- Auto-suggested by `init` after init completes
- Before first `/psd:deploy` (deploy will redirect here if env not ready)
- Anytime the user hits "command not found" or env-related errors

## Pre-flight gates
- `.planning/PROJECT.md` must exist (so we can read the Stack section). Else suggest `/psd:init` first.
- **Skip-path:** if `.planning/DOCTOR.md` exists AND it's <24h old AND `--force` not passed → print "Env recently checked (see DOCTOR.md). Pass --force to re-check." and exit.

## Subagent dispatch
Spawn `doctor`:

```
You are doctor for this PSD project.

Read yourself:
- .planning/PROJECT.md (Stack section + Required CLIs list)
- .planning/STATE.md (so you know which milestone/phase context applies)
- existing .vercel/project.json, supabase/config.toml, .env / .env.local (if present)
- existing .planning/DOCTOR.md (if --force or stale, you'll overwrite it)

Read @$HOME/.claude/workflows/doctor.md for the protocol.

Run checks in this order, surfacing each result clearly to the user:

1. CLI tooling check (per "Required CLIs" in PROJECT.md)
2. Vercel project link (vercel link if .vercel/project.json absent and Stack mentions Vercel)
3. Supabase project link (supabase init / supabase link if Stack mentions it)
4. .env walkthrough (per service in Stack)
5. vercel env pull/push sync
6. Optional dev-server smoke test

For each: prefer companion skill if available (vercel:bootstrap, vercel:env, supabase:supabase). Fall back to bash + plain-English instructions if companion missing.

Write phases/Phase {N} or .planning/DOCTOR.md per template below.

Report back in <=200 words: what's installed, what's missing, what was provisioned, what the user needs to do manually.
```

## Companion delegation (suggestion-mode, per workflows/companion-skills.md)

If any of these are in the available-skills list, the orchestrator prints a one-line FYI BEFORE dispatching `doctor`:

- `vercel:bootstrap` — preferred for first-time Vercel + linked-resource setup
- `vercel:status` — current Vercel state
- `vercel:env` — env management
- `supabase:supabase` — Supabase ops

`doctor` itself uses these companions if available; otherwise runs bash directly.

## Check sequence

### 1. CLI tooling
For each tool listed in PROJECT.md "Required CLIs":
- Run `<tool> --version` to verify presence + version
- For tools that need login (vercel, gh, supabase): check login state with `<tool> whoami` or equivalent
- If missing: surface platform-specific install command (brew on macOS, apt/yum on Linux, winget on Windows)
- If present but logged out: surface login command

Example output:
```
✓ node 22.11.0
✓ git 2.43.0
✗ vercel — NOT INSTALLED
   Install: npm i -g vercel
✓ vercel — installed but NOT LOGGED IN
   Login: vercel login
```

### 2. Vercel project link
If Stack mentions Vercel AND no `.vercel/project.json`:
- Run `vercel link` (interactive) or delegate to `vercel:bootstrap`
- After link: `cat .vercel/project.json` to confirm

### 3. Supabase project link
If Stack mentions Supabase AND no `supabase/config.toml`:
- Run `supabase init` for local config
- Then `supabase link --project-ref <ref>` (ask user for project ref or pull from Vercel env)

### 4. `.env` walkthrough
For each external service in PROJECT.md Stack:
- Identify required env var names (e.g., `OPENAI_API_KEY`, `STRIPE_SECRET_KEY`, `SUPABASE_SERVICE_ROLE_KEY`)
- For each: check if already in `.env.local`. If yes, mask and confirm. If no:
  - Show the dashboard URL where the user fetches it (e.g., "Get your Anthropic API key at https://console.anthropic.com/settings/keys")
  - Wait for user to paste it (via AskUserQuestion or prompt for manual edit + re-run)
  - Append to `.env.local` with the right name

### 5. `vercel env pull/push` sync
If Vercel is linked:
- `vercel env pull .env.local` — pull existing Vercel env to local
- For new local-only keys, prompt user: "Add `<KEY>` to Vercel? [yes/no]"; on yes: `vercel env add <KEY>`

### 6. Dev-server smoke test (optional, only if `--smoke-test` passed)
- Detect dev command: `package.json` scripts.dev, or fall back to `npm run dev`
- Run for 10 seconds, check exit/stderr for env-missing errors
- Stop the server cleanly

## Artifact template

### `.planning/DOCTOR.md`
```markdown
# Doctor — Env Health

**Last check:** <ISO>
**Verdict:** <READY | NEEDS-ATTENTION>

## CLI tooling
- ✓ <tool> <version>
- ✗ <tool> — <issue + fix>

## Project links
- Vercel: <linked to project-name | NOT LINKED>
- Supabase: <linked to project-ref | NOT LINKED | NOT IN STACK>

## Environment variables (.env.local)
- ✓ <KEY> (set)
- ✗ <KEY> (missing — get from <dashboard URL>)

## Vercel env sync
- Last `vercel env pull`: <date>
- Local-only keys (not yet pushed): <list, or "none">

## What you need to do
- [ ] <action 1>
- [ ] <action 2>
- (or "Nothing! Env is ready. Run /psd:deploy.")
```

## Hand-off

After `doctor` runs:
- `deploy` reads `DOCTOR.md` and skips its own pre-flight if `Verdict: READY` and DOCTOR.md is <24h old
- The user sees the verbose env state once and doesn't have to think about it again until something changes

## Hard rules

- **Never write to user's `.env` without explicit confirmation** — even if the user pastes a key, show what's about to be written and confirm
- **Never push env to Vercel without explicit confirmation** — same reasoning
- **Never log full secret values** in DOCTOR.md or anywhere else; mask with `<set>` or `<missing>` only
- Cap DOCTOR.md at ~120 lines
- Always exit with a clear "what to do next" — even if everything passes, suggest `/psd:deploy`
