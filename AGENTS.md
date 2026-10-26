# Codex instructions for QuizHub QA

This checkout is Sơn's long-lived QA workspace on `qa/khanhson2005`.

## Scope and branch

- Keep QA work on `qa/khanhson2005`: tests, acceptance criteria, QA records, and configuration used to run QA.
- `main` is the source of app updates. When authorized to sync, merge `main` into this QA branch. Never merge, cherry-pick, or rebase QA changes into another branch, including `main`.
- Sơn authorizes routine commits and pushes of scoped QA changes to `origin/qa/khanhson2005` without asking again. Never push QA work to `main` or another branch. Open a PR, publish, or write to any other remote service only when Sơn explicitly requests that specific action.
- Do not change runtime app behavior, production configuration, or dependencies unless Sơn separately requests that change. Authorization for one task does not expand its scope.
- Do not install packages or SDKs unless explicitly requested. Prefer existing tools and targeted checks.

## QA ownership

- Devs own and maintain unit/component tests for their Dart modules. Sơn owns acceptance criteria, manual/API/UI/E2E checks, evidence, defect reports, retests, and regression decisions. QA may add narrow, test-only regression coverage when the task authorizes it.
- Treat unimplemented placeholders as `WAITING`, not failures. Resolve expected behavior from a requirement or owner before filing a business-rule bug.
- Never report `PASS` from code inspection, a test file's existence, or an unrun command. Record the exact tested commit SHA, command and exit code, environment/device/API host, case IDs, and evidence. Use `NOT RUN` or `BLOCKED` when appropriate; mask credentials and tokens.
- Preserve screenshots that show test failures; do not delete them during cleanup. Selected error screenshots may be committed on `qa/khanhson2005` under `docs/qa/evidence/<date>/`; keep bulk logs and temporary files in ignored `qa-artifacts/`. Redact credentials, tokens, and personal device data. Push these QA commits only to `origin/qa/khanhson2005`.
- When Sơn explicitly authorizes installing the QA app for native testing, use a separate application ID so it does not overwrite the main app. Uninstall the QA app after testing unless Sơn asks to keep it; retain the test evidence.
- The canonical bug and progress tracker is the [TESTING LỖI tab](https://docs.google.com/spreadsheets/d/1URTpbSX2k_04dvurVlJUbkP2iDILs618CKItSpDxjq4/edit#gid=2122578546). The coordinator is authorized to update this tab for QA bug/progress tracking without re-asking; this does not authorize writes to other tabs or services. Update an existing issue by its stable issue key; record confirmed bugs with tested SHA, environment, reproduction steps, expected/actual result, owner, and evidence. Update status, retest result, last-updated date, and notes only from observed checks. Do not mark Fixed/Closed without an observed fix and passing retest. Keep static candidates and unclear business rules waiting; preserve the sheet structure, validations, and other team tabs; do not create duplicate issue rows.

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
