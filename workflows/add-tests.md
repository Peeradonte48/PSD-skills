# Workflow: psd-add-tests

Generate automated tests from a phase's `VERIFICATION.md` criteria. Opt-in skill that runs **after `psd-verify`** and **before `psd-ship`**. Skipped if the project has no detectable test framework.

## Why this exists

Manual UAT (`psd-verify`) confirms the phase works once. Automated tests prevent regression. For non-technical users especially, "I don't know how to write tests" shouldn't mean "no regression coverage."

The tester reads passing UAT criteria and writes one test per critical criterion in the project's existing framework. It does NOT achieve high coverage — that's a separate concern.

## Pre-flight gates
1. `phases/Phase {N}/PLAN.md` and `phases/Phase {N}/VERIFICATION.md` must exist.
2. VERIFICATION.md must have `Result: PASS` or `Result: PARTIAL` — there must be at least some passing criteria to test.
3. **Test framework detection** — Glob for one of:
   - JS/TS: `vitest.config.*`, `jest.config.*`, `playwright.config.*`, or `package.json` with `vitest|jest|playwright|@testing-library` in deps
   - Python: `pyproject.toml` with `pytest`, or `tests/conftest.py`
   - Other: skip with one-liner "no detectable test framework — please install one before re-running"
4. **Skip-path:** if `phases/Phase {N}/.tests-generated` marker exists AND `--force` not passed → "Tests already generated. Pass --force to regenerate." and exit.

## Subagent dispatch
Spawn `psd-tester`:

```
You are psd-tester for Phase {N}.

Read yourself:
- phases/Phase {N}/PLAN.md (success criteria, plan list)
- phases/Phase {N}/VERIFICATION.md (which criteria passed)
- phases/Phase {N}/plans/*.md (per-plan test criteria + `files:` lists)
- One existing test file from the project (Glob the test dir, Read one) to learn the project's testing style + import conventions

Detected test framework: <vitest | jest | pytest | playwright | ...>

Read @$HOME/.claude/workflows/add-tests.md for the protocol.

Process:
1. Build a test list from VERIFICATION.md's PASS items + per-plan "Test criteria" sections.
2. For each, decide: is this a unit test, integration test, or E2E test? Match the project's existing patterns.
3. Write tests to the project's conventional test directory using the same import style and assertion library the existing tests use.
4. One test file per phase plan ID OR one merged file per phase, depending on what the project's existing pattern looks like.
5. Run the tests once to confirm they pass (`npm test`, `pytest`, etc.) — if any fail, debug only the test (not source) for ≤2 attempts; else mark as TODO with reason.
6. Stage + commit the test files: `test: phase {N} criteria coverage`
7. Touch a marker file: `phases/Phase {N}/.tests-generated`

Report back in <=200 words: tests written (count), pass count, any TODOs, commit SHA.
```

## Test scope discipline (binding)

- **Generate ≤1 test per VERIFICATION.md PASS criterion.** Don't write 5 tests per criterion.
- **Match the project's style.** Read one existing test before writing. If the project uses `describe` / `it`, use that. If it uses bare `test()` calls, use that.
- **Don't generate setup boilerplate the project already has** — assume `vitest.setup.ts` etc. is already wired up.
- **No mocking unless the project already mocks.** If the existing tests use real DB / real API, follow the same. Don't introduce new mock infrastructure.
- **If a criterion is hard to automate** (e.g., "the page looks good", "load time feels snappy"), mark it as `// TODO: manual UAT only` in a comment — don't try to write a fake test.

## Hand-off

Tests are committed as `test: phase {N} criteria coverage`. They land in the same branch as the phase work, so `psd-ship` includes them in the PR automatically.

`psd-ship`'s PR body template includes "Test plan" — when `.tests-generated` exists, the shipper notes "Automated tests added (`tests: <count>`); see `<test files>`."

## Hard rules
- **Don't modify source files.** Tests only.
- **Don't try to hit ≥80% coverage** or any specific coverage target — write one test per VERIFICATION criterion, that's it.
- **Don't add new test framework to the project.** If none exists, skip.
- **Tests must pass when generated.** Run them once before committing. Failed tests get a TODO comment + report in the summary, not a green commit.
- **Cap at 25 generated tests.** If criteria exceed 25, write the most critical 25 and TODO the rest.
- **One commit.** Don't generate test for plan 1, commit, then plan 2, commit. Atomic.
