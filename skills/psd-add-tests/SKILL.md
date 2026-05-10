---
name: psd-add-tests
description: Generate automated tests from a phase's VERIFICATION.md PASS criteria. Matches project's existing test framework + style. Opt-in between verify and ship.
argument-hint: "[phase] [--force]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Task
---

<objective>
Turn manually-verified UAT criteria into automated tests. The tester subagent detects the project's test framework, matches its style, generates one test per PASS criterion (capped at 25), runs them once before committing.

Use case: non-technical users get regression protection without having to know how to write tests. Run after `psd-verify` and before `psd-ship`.

Orchestrator role: validate state, detect test framework, dispatch `psd-tester`. Skips if no test framework is detectable.
</objective>

<execution_context>
@$HOME/.claude/workflows/add-tests.md
</execution_context>

<process>
1. **Pre-flight gates** (per workflows/add-tests.md):
   - `phases/Phase {N}/VERIFICATION.md` must exist with `Result: PASS` or `PARTIAL`.
   - **Detect test framework** via Glob (`vitest.config.*`, `jest.config.*`, `playwright.config.*`, `package.json` deps, `pyproject.toml` for pytest, etc.). If none found → print "No detectable test framework. Install vitest/jest/pytest/playwright before re-running." and exit.
   - **Skip-path:** if `phases/Phase {N}/.tests-generated` marker exists and `--force` not passed → print "Tests already generated. Pass --force to regenerate." and exit.

2. **Companion check (suggestion mode):** scan the available-skills list. If `superpowers:test-driven-development` is listed, print:

   > FYI: `superpowers:test-driven-development` is also available — TDD-first instead of after-the-fact. For new features built test-first, run that earlier in the loop; otherwise continuing with `psd-add-tests` (after-the-fact tests from VERIFICATION.md).

   If not listed, skip silently.

3. **Dispatch `psd-tester`** with phase number, detected framework, and `--force` if passed.

4. **Report** the tester's ≤200-word summary verbatim.

Preserve all gates: never modify source files; never ship red tests as green; one atomic commit; never auto-delegate to companion (suggestion only).
</process>
