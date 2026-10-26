# Web UI evidence summary — 2026-10-26

**Tested app source:** `b949513b254bee55a3887e619786ea91f85b477f`. Browser preview ran tracked `lib/` and `assets/` at that SHA. Flutter 3.41.6 / Dart 3.11.4, Chromium headless via Playwright MCP. Lecturer viewport 1280×720; student viewport 390×844. Backend was `PreviewBackend` in RAM; no API host or native device.

| Case | Observed result |
|---|---|
| `WEB-BANK-001` | Lecturer bank screen showed approved sessions and subject filters. |
| `WEB-PRACTICE-001` | Lecturer selected B (`O(log n)`) and submitted; result showed “Chính xác!”, explanation, and progress 1/2. |
| `WEB-RATE-001` | Rating 4 completed; rating action changed to “Đã đánh giá”. |
| `WEB-STATS-001` | Statistics showed 51 attempts, 3 ratings, and user #1 rating 4. |
| `WEB-AI-001` | Lecturer refined a question using a preset; suggestion showed 92% confidence. After confirmation, practice showed updated question prefix and explanation. |
| `WEB-EXAM-001` | Lecturer generated “QA MCP 26-10” for IT3011 / class 171146 (selected automatically); preview showed two questions and AI actions. |
| `WEB-EXAM-002` | Returning to the exam list showed the generated exam. |
| `WEB-ROLE-001` | Student bank screen had zero exam shortcut controls. |
| `WEB-ROLE-002` | Student practice had zero AI actions and no submit action before selecting an answer. |
| `WEB-SUBMISSION-001` | Pending submission detail showed edit and delete actions. |
| `WEB-SUBMISSION-002` | Saving title “QA MCP Bảng băm 26-10” updated the detail screen and showed success feedback. |
| `WEB-SUBMISSION-003` | Resolved submission detail had zero edit and delete actions. |

Selected screenshots:

- [Generated exam preview](exam-generated.png) — `WEB-EXAM-001`.
- [Student practice before selection](student-practice.png) — `WEB-ROLE-002`; this screenshot is before answering and does not evidence the lecturer answer result.

The detailed Playwright snapshots, console logs, and build logs remain in ignored `qa-artifacts/2026-10-26/web-ui/`; no failing screenshot was produced. The browser report records preview limitations and unverified observations.
