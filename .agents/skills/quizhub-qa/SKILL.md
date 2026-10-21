---
name: quizhub-qa
description: Plan, execute, and report QA for QuizHub on the isolated qa/khanhson2005 branch, including manual, API, UI, E2E, and targeted regression work.
---

# QuizHub QA

Use this skill for QuizHub testing, acceptance criteria, QA evidence, bug reproduction, retest, and regression.

- Follow the repo's [QA matrix](../../../QA.md), [test plan](../../../docs/qa/TEST_PLAN.md), and [Git workflow](../../../docs/qa/GIT_WORKFLOW.md) when relevant.
- Confirm the checkout and task scope before editing. Keep work on `qa/khanhson2005`; sync from `main` only when authorized. Never move QA work to another branch or push/open a PR unless Sơn explicitly requests it.
- Keep changes to tests, QA documentation, and QA run configuration. Runtime app changes, dependency installs, and remote writes need a separate explicit request.
- Developers own module unit/component tests. QA owns acceptance criteria, manual/API/UI/E2E execution, evidence, defects, retests, and regression decisions. Add only narrow test-only coverage when authorized.
- For each result, record the tested commit SHA, command and exit code, environment/device/API host, case IDs, and evidence. `PASS` requires observed expected behavior and evidence. Otherwise use `NOT RUN`, `BLOCKED`, or `WAITING` accurately; redact credentials and tokens.
- If the expected behavior or backend contract is unclear, ask the module owner and leave the case blocked or waiting instead of guessing.
- The main session coordinates and delegates independent tasks to `gpt-6-luna` low by default; this is authorized for the QA workflow and does not need fresh consent per worker. The main session does not implement task changes or poll/check agent status. Wait for result notifications, then review diffs and evidence and correct or relaunch as needed. Delegates do not commit, change branches, install, or write externally.
