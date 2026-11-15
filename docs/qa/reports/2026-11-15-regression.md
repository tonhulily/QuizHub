# Regression QA — 2026-11-15

- **TESTED_SHA:** `adde556e2ef6e481fd7145588db878012673b059`
- **Merged upstream main:** `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3`
- **Branch / worktree:** `qa/khanhson2005`; clean before checks. This delegated work adds only this report and its owned evidence files; no other paths were changed by this run. No commit or push.
- **Environment:** Linux x86_64 / WSL2 per configured QA runner; Flutter 3.41.6 stable / Dart 3.11.4, verified from the local Flutter version marker and Dart executable; isolated `.qa-tools` config/cache. No API host or device used.

## Cache gate and blocked checks

Before invoking Flutter, compared `.dart_tool/package_config.json` to `pubspec.lock` offline; the check exited 0 and details are in [cache-gate.txt](../evidence/2026-11-15/regression/cache-gate.txt). Excluding root package `quizhub`, package config has 134 dependencies against 136 lockfile packages. `phosphor_icons` 3.0.1 and `stomp_dart_client` 3.0.1 are absent from both config and cache. `web_socket` 1.0.1 is absent from config but present in cache. The config also includes `phosphor_flutter` 2.1.0 without a lock entry. Five configured hosted packages are at older versions than the lockfile: `intl`, `matcher`, `meta`, `test_api`, and `vector_math`. Thus **Flutter test and analyze were BLOCKED and not invoked**. No package installation, pub get, download, cache repair, or config/runtime change was made.

## Executed checks

| Command | Exit | Observed result |
|---|---:|---|
| `.qa-tools/flutter/bin/dart format --output=none --set-exit-if-changed lib test qa/repro` | 1 | Check-only; 186 files scanned, 4 reported as needing formatting: `lib/core/bloc/paged_cubit.dart`, `lib/data/repositories/like_state_store.dart`, `lib/features/question_bank/widgets/question_social_bar.dart`, `test/core/paged_cubit_test.dart`. No files changed. Evidence: [dart-format.txt](../evidence/2026-11-15/regression/dart-format.txt). |
| `python3 qa/api/test_collection.py` | 0 | 3 offline collection linter tests passed. Not API/backend acceptance. Evidence: [api-collection.txt](../evidence/2026-11-15/regression/api-collection.txt). |
| `python3 -m unittest discover -s qa/fixtures -p 'test_*.py' -v` | 0 | 6 offline fixture-generator tests passed. No fixture generation command was run. Evidence: [fixtures.txt](../evidence/2026-11-15/regression/fixtures.txt). |

## Existing issue retests

| Issue | Result | Reason |
|---|---|---|
| QH-QA-001 | NOT RUN | Flutter cache gate mismatch; Dart harness not invoked. |
| QH-QA-002 | NOT RUN | Flutter cache gate mismatch; Dart harness not invoked. |
| QH-QA-003 | NOT RUN | Flutter cache gate mismatch; Dart harness not invoked. |
| QH-QA-004 | NOT RUN | Flutter cache gate mismatch; widget test not invoked. |

No issue status or tracker was changed. No bug was closed or marked fixed based on source inspection.

**Conclusion:** BLOCKED for Flutter regression/analyzer and all four issue retests due to the package cache/lockfile mismatch. The offline Python checks passed; the Dart format check exited 1. No API, UI, device, or native behavior was tested.
