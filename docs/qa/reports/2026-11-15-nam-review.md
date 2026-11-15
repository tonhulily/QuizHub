# Regression QA — Nam / Search, Notifications, FCM

- **Tested source SHA:** `639da129d89e8290c13b63af3d36045309b38fd6` (feature/search snapshot).
- **Comparison baseline:** upstream `main` `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3`; stale local `main` was excluded.
- **Environment:** Linux x64; Flutter 3.41.6, Dart 3.11.4; dependencies were prepared by the coordinator. Test command used `--no-pub` and local mocks/fakes only. No backend/API, A/B account, or device/push run.
- **Final snapshot state:** four app runtime files match pristine source SHA contents; only three narrow regression test files remain added in the ignored snapshot. Fingerprints: [source hashes](../evidence/2026-11-15/nam/source-fingerprints.txt). The regression probes are preserved as [readable evidence copies](../evidence/2026-11-15/nam/repros/); their SHA-256 values match the tested copies. Cleanup removed all runtime-fix commits; the QA history retains only the merge at `adde556e2ef6e481fd7145588db878012673b059` and test-only commit `999a1678206a6b0d5589cf2c97a0f677ef8bb017`. No app fix is proposed or included.

## Result

The focused baseline command ran against pristine runtime files with the finalized regression tests and exited **1: 7 failed, 2 passed**. Five lifecycle cases emitted `Bad state: Cannot emit new states after calling close`; the delayed second notification tap was not handled; the notification empty state overflowed. Both small-viewport search controls passed. The [baseline evidence](../evidence/2026-11-15/nam/baseline-safecompletion.txt) records the command, actual output, expected results, and raw-log path.

The full suite was **NOT RUN against the final pristine snapshot**. Earlier experimental runs used an isolated app patch and are excluded from QA acceptance; their results do not establish a fix or pass. No app runtime files were edited in the final snapshot state. The finalized regression tests remain available for Nam to use when fixing the defects.

## Notification and FID finding

`NotificationCubit` fetches `GET /notifications`, updates read state, and refreshes on foreground push. The client does not create notifications when comments or friend requests are made. Those business requests can succeed while notification generation/list persistence and Firebase delivery remain backend responsibilities. `GET /notifications` with `items: []` is a valid empty result and does not by itself demonstrate a client or backend defect.

The client sends FID in login and calls `POST /devices/fid` when signed in. HTTP 200 establishes request acceptance only; it does not establish token routing, project/device binding, notification generation, or FCM delivery. Missing push remains **WAITING** on backend delivery logs or a controlled native test. No production API was used.

## Confirmed baseline defects — proposed tracker rows

These are reproducible client-side failures on pristine source with mock/widget harnesses. Suggested owner for all is **Nam**. Priorities below are QA proposals; no tracker update was made.

| Proposed key | Priority | Steps | Expected | Actual | Evidence |
|---|---|---|---|---|---|
| QH-QA-006 — Push settings async close | Major / Medium | Open push settings; hold GET or PUT mock; close/dispose cubit; complete request successfully or with error. | Late completion is safely ignored after disposal. | Four paths emit `Bad state: Cannot emit new states after calling close`. | [baseline result](../evidence/2026-11-15/nam/baseline-safecompletion.txt), [repro tests](../evidence/2026-11-15/nam/repros/async_close_lifecycle_test.dart.txt) |
| QH-QA-007 — Saved-search delete async close | Major / Medium | Start saved-search DELETE; close cubit before mock request fails. | Late failure does not emit after disposal. | `GlobalSearchCubit.deleteSavedSearch` emits into closed cubit and throws. | [baseline result](../evidence/2026-11-15/nam/baseline-safecompletion.txt), [repro tests](../evidence/2026-11-15/nam/repros/async_close_lifecycle_test.dart.txt) |
| QH-QA-008 — Queued notification tap | Major / Medium | Hold navigation for notification 1; tap notification 2 before navigation 1 completes. | Both notification IDs are handled in order. | Expected `[1,2]`; observed `[1]`. | [baseline result](../evidence/2026-11-15/nam/baseline-safecompletion.txt), [repro test](../evidence/2026-11-15/nam/repros/fcm_pending_queue_test.dart.txt) |
| QH-QA-009 — Notification empty-state overflow | Minor / Low | Retry a notification load to an empty result at 320×640 viewport. | Empty state is visible without overflow. | RenderFlex overflowed by 917 px. | [baseline result](../evidence/2026-11-15/nam/baseline-safecompletion.txt), [repro test](../evidence/2026-11-15/nam/repros/search_notifications_ui_test.dart.txt) |

## Executed check

Working directory: ignored `qa-artifacts/2026-11-15/nam-source/`. Environment used workspace `.qa-tools` paths for `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, and `PUB_CACHE`, plus `FLUTTER_SUPPRESS_ANALYTICS=true` and `CI=true`.

`/home/khanhson2005/projects/QuizHub/.qa-tools/flutter/bin/flutter test --no-pub --reporter expanded test/qa/async_close_lifecycle_test.dart test/qa/fcm_pending_queue_test.dart test/qa/search_notifications_ui_test.dart` — **exit 1, 7 failed / 2 passed** against pristine runtime, with loopback socket permission. The default sandbox invocation failed to bind a temporary `127.0.0.1` test socket; the approved local rerun completed. No external endpoint was contacted. Full raw output is in ignored `qa-artifacts/2026-11-15/nam-source/baseline-safecompletion.log`.

`PUSH-01` notification delivery and `SEARCH-01` product acceptance remain **WAITING**: no owner-defined notification-generation rule, backend observation, A/B access, or native delivery test was available. Defects above are **confirmed / not fixed**; integration/retest has not run. No tracker or remote status was changed.
