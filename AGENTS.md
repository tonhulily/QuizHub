# Codex instructions for QuizHub QA

This checkout is Sơn's long-lived QA workspace on `qa/khanhson2005`.

## Scope and branch

- Keep QA work on `qa/khanhson2005`: tests, acceptance criteria, QA records, and configuration used to run QA.
- `main` is the source of app updates. When authorized to sync, merge `main` into this QA branch. Never merge, cherry-pick, or rebase QA changes into another branch, including `main`.
- Do not push, open a PR, publish, or write to a remote service—including through a plugin or connector—unless Sơn explicitly requests that action. This applies to QA branch contents and reports.
- Do not request the same authorization again when Sơn has already authorized it in the active task. A request for a local commit authorizes that commit only, never a remote push.
- Do not change runtime app behavior, production configuration, or dependencies unless Sơn separately requests that change. Authorization for one task does not expand its scope.
- Do not install packages or SDKs unless explicitly requested. Prefer existing tools and targeted checks.

## QA ownership

- Devs own and maintain unit/component tests for their Dart modules. Sơn owns acceptance criteria, manual/API/UI/E2E checks, evidence, defect reports, retests, and regression decisions. QA may add narrow, test-only regression coverage when the task authorizes it.
- Treat unimplemented placeholders as `WAITING`, not failures. Resolve expected behavior from a requirement or owner before filing a business-rule bug.
- Never report `PASS` from code inspection, a test file's existence, or an unrun command. Record the exact tested commit SHA, command and exit code, environment/device/API host, case IDs, and evidence. Use `NOT RUN` or `BLOCKED` when appropriate; mask credentials and tokens.

## Delegation and edits

- The main session coordinates QA and spawns delegates; it does not implement task changes itself. Delegation to `gpt-6-luna` at low reasoning effort is authorized by this QA workflow and need not be re-approved for each worker. Assign independent tasks with disjoint file ownership.
- Do not monitor agents: no status polling, `list_agents`, progress chasing, or reading intermediate files. Wait for result notifications, then review the returned diff and evidence; correct or relaunch a delegate as needed.
- Delegates must stay within assigned paths, make no branch/commit changes, and perform no push, install, or external write. The coordinator owns integration and commits.
- Read existing instructions and the relevant code before editing. Keep changes scoped, preserve unrelated work, and run only checks justified by the request and available environment.
- Write user-facing QA notes in concise Vietnamese by default.

## References

- [QA matrix and current findings](QA.md)
- [QA test plan](docs/qa/TEST_PLAN.md)
- [QA Git workflow](docs/qa/GIT_WORKFLOW.md)
- [QuizHub QA skill](.agents/skills/quizhub-qa/SKILL.md)
