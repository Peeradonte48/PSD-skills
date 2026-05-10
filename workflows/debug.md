# Workflow: psd-debug

Diagnose and fix something broken. Works inside or outside a PSD project. Always asks for confirmation before applying a fix — safer for non-technical users.

## When to use
- An error appears (red text in terminal, broken page, failing test)
- Something used to work and now doesn't
- A feature behaves wrong (button doesn't respond, data doesn't save)
- An executor halted mid-phase with a failure

## Pre-flight (no hard gates — debug is the safety net)
- `.planning/` is **optional**. If present, debug uses STATE/CHECKPOINT for context. If not, debug just uses git + the user's symptom description.
- Working tree may be dirty (often is, that's why we're debugging).

## Subagent dispatch
Spawn `psd-debugger`:

```
You are psd-debugger.

User's symptom: <$ARGUMENTS verbatim, free text>

Read yourself (in this order, stop when you have enough):
1. .planning/CHECKPOINT.md last 5 entries (if .planning/ exists)
2. .planning/STATE.md (if exists)
3. git log --oneline -20
4. git status --porcelain
5. Recent unstaged diff: `git diff --stat HEAD`
6. Run the failing command if user provided one (read-only inspection if possible)

Read @$HOME/.claude/workflows/debug.md for the protocol.

Process (scientific method, brief):
1. RESTATE the symptom in your own words to confirm understanding.
2. ASK 2-4 targeted questions via AskUserQuestion to fill gaps:
   - When did it last work? (just now, never, after some change)
   - What did you do right before it broke? (exact action)
   - Exact error text / what you see (paste or describe)
   - File/page/screen where it appears
3. FORM A HYPOTHESIS — one specific testable cause.
4. INVESTIGATE — read at most 3-5 relevant files. Confirm or refute the hypothesis.
   - If refuted: form a new hypothesis. Max 2 hypothesis cycles before reporting "stuck."
5. PROPOSE A FIX in plain English (one paragraph, no jargon-dumping):
   - "What's wrong:" one line
   - "What I'll change:" 1-3 bullets, plain English
   - "Why this fixes it:" one line
6. ASK CONFIRMATION via AskUserQuestion: [Apply this fix | Show me the code first | No, just diagnose]
7. If APPLY:
   - Implement the minimal change (touch as few files as possible)
   - Run obvious validation: typecheck (`tsc --noEmit`), lint, the failing test if any
   - Stage the changed files, commit with message: `fix: <one-line symptom>` (no Claude trailer unless project convention dictates)
   - Verify with `git log -1`
8. If SHOW CODE FIRST: print the proposed diff (or new content) and re-ask.
9. If JUST DIAGNOSE: write nothing; report the diagnosis only.

Report back in <=200 words: symptom restated, root cause one-liner, fix applied (yes/no with commit SHA), test status, what to do next.
```

## Hard rules for the debugger
- **Never auto-apply** without an explicit "Apply this fix" answer
- **Never amend** existing commits
- **Never push**
- **Never `git add -A`** — only the files in the proposed fix
- **Never modify .planning/STATE.md to advance phase** (debug is orthogonal to phase progression)
- If debug touches code that's part of an in-flight phase plan, mention it in the report so the user knows the planner's spec may need updating
- Max 2 hypothesis cycles. If still stuck, REPORT STUCK with what you've learned and suggest:
  - Re-running with more info from the user
  - Checking docs / external resource
  - Reverting the most recent commit (`git revert HEAD`) as last resort

## State touch (minimal)
After a successful debug-and-apply:
- If `.planning/STATE.md` exists, append to "Recent decisions": `Debug fix <ISO date>: <one-line symptom> → <commit sha>`
- Do NOT change `last_skill` (keep whatever was active so `psd-resume` can return to the in-flight phase). Optionally add a `last_debug: <commit sha>` line.

## Why ask before applying?
Non-technical users get burned by silent "fixes" that change semantics they didn't expect. The 5-second confirmation step is cheap insurance and turns the debugger into a teaching tool ("here's what I think and why").

## Failure modes
- User can't describe the symptom clearly → ask one clarifying question, then if still vague, suggest they paste the literal error text
- Hypothesis cycles exhausted → report stuck (don't keep guessing)
- Applied fix didn't actually fix it → report; user can run `/psd-debug` again with the new symptom; if the fix made things worse, suggest `git revert HEAD`
