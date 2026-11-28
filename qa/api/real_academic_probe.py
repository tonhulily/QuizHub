#!/usr/bin/env python3
"""Disposable student question-bank smoke using accounts supplied on stdin."""
import argparse
import datetime as dt
import json
import re
import subprocess
import sys
import urllib.parse
import uuid
from pathlib import Path

import real_student_probe as http


def record(cases, case_id, method, path, expected, status, body, error=None, force=None, **flags):
    outcome = force or (
        "BLOCKED" if error or status is None else
        "PASS" if http.envelope_ok(status, body) else "FAIL"
    )
    cases.append({
        "case_id": case_id, "method": method, "path": path, "status": outcome,
        "http_status": status,
        "business_code": http.safe_code(body.get("code")) if isinstance(body, dict) else None,
        "expected": expected,
        "observed": http.response_summary(body) if error is None else {"transport_error": error},
        "timestamp_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        **flags,
    })
    return outcome


def reject_result(status):
    return "BLOCKED" if status is None else "PASS" if status == 403 else "FAIL"


def body_data(body):
    return body.get("data") if isinstance(body, dict) and isinstance(body.get("data"), (dict, list)) else None


def safe_list(value, key=None):
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        value = value.get(key or "items")
        return value if isinstance(value, list) else []
    return []


def request(base, method, path, token, payload=None):
    return http.request(base, method, path, token=token, payload=payload)


def proposal_payload(course_class_id, marker):
    return {
        "course_class_id": course_class_id,
        "title": f"QA academic probe {marker}",
        "content": "Temporary disposable API smoke proposal.",
        "questions": [
            {
                "content": f"QA {marker}: Which is a software testing activity?",
                "options": [
                    {"key": "A", "text": "Checking behavior against requirements", "is_correct": True},
                    {"key": "B", "text": "Removing all test records", "is_correct": False},
                ],
                "explanation": "Tests compare observed behavior with expected behavior.",
                "llm_generated": False, "confidence": 3.0,
            },
            {
                "content": f"QA {marker}: What does a regression test check?",
                "options": [
                    {"key": "A", "text": "Whether a change broke existing behavior", "is_correct": True},
                    {"key": "B", "text": "Whether source files have a new name", "is_correct": False},
                ],
                "explanation": "Regression tests catch unintended changes to prior behavior.",
                "llm_generated": False, "confidence": 3.0,
            },
            {
                "content": f"QA {marker}: Why keep a test case reproducible?",
                "options": [
                    {"key": "A", "text": "To compare results consistently", "is_correct": True},
                    {"key": "B", "text": "To avoid recording expected behavior", "is_correct": False},
                ],
                "explanation": "Reproducible cases make observed results comparable.",
                "llm_generated": False, "confidence": 3.0,
            },
        ],
    }


def update_payload(course_class_id, marker, questions):
    rows = []
    for i, q in enumerate(questions):
        opts = q.get("options") if isinstance(q.get("options"), list) else []
        rows.append({
            "question_id": q.get("question_id") or q.get("id"),
            "content": q.get("content", ""),
            "media_urls": q.get("image_urls", q.get("media_urls", [])) or [],
            "options": [{k: o[k] for k in ("key", "text", "is_correct", "media_url", "media_id") if k in o}
                        for o in opts if isinstance(o, dict)],
            "explanation": q.get("explanation"),
            "source": "HOMO_SAPIENS",
            "confidence": q.get("confidence", q.get("confidence_score", 3.0)),
        })
    return {
        "course_class_id": course_class_id,
        "title": f"QA academic probe {marker} updated",
        "content": "Temporary disposable API smoke proposal.",
        "questions": rows,
    }


def detail_state(data, session_id, title=None):
    if not isinstance(data, dict):
        return False, None, 0
    session_ok = data.get("session_id", data.get("id")) == session_id
    title_ok = title is None or data.get("title") == title
    questions = data.get("questions") if isinstance(data.get("questions"), list) else []
    return session_ok and title_ok, data.get("status"), len(questions)


def call_detail(base, token, session_id):
    return request(base, "GET", f"/sessions/my-submissions/{session_id}", token)


def confirm_pending_in_list(base, token, session_id):
    status, body, error = request(base, "GET", "/sessions/my-submissions?status=PENDING&limit=50", token)
    rows = safe_list(body_data(body), "contents") or safe_list(body_data(body), "items")
    found = http.envelope_ok(status, body) and any(
        isinstance(row, dict) and row.get("session_id", row.get("id")) == session_id for row in rows
    )
    return status, body, error, found


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    if args.self_check:
        payload = proposal_payload(42, "offline")
        assert payload["course_class_id"] == 42 and len(payload["questions"]) == 3
        assert all(len(q["options"]) == 2 and sum(o["is_correct"] for o in q["options"]) == 1 for q in payload["questions"])
        updated = update_payload(42, "offline", [{"question_id": 1, **q} for q in payload["questions"]])
        assert len(updated["questions"]) == 3 and all(q["source"] == "HOMO_SAPIENS" for q in updated["questions"])
        private = http.response_summary({"email": "private@example.test", "message": "private@example.test", "data": {"password": "secret"}})
        assert "private@example.test" not in json.dumps(private) and "secret" not in json.dumps(private)
        assert reject_result(200) == "FAIL" and reject_result(403) == "PASS" and reject_result(None) == "BLOCKED"
        print("self-check PASS")
        return 0

    try:
        supplied = json.load(sys.stdin)
        accounts = supplied["accounts"]
        base = (supplied.get("base_url") or http.default_base_url()).rstrip("/")
        if not isinstance(accounts, list) or len({a.get("alias") for a in accounts if isinstance(a, dict)}) != len(accounts) or any(
            not isinstance(a, dict) or a.get("alias") not in ("son", "nam")
            or not isinstance(a.get("email"), str) or not isinstance(a.get("password"), str)
            for a in accounts
        ) or not any(a.get("alias") == "son" for a in accounts):
            raise ValueError("expected son account and optional nam account")
        parsed = urllib.parse.urlparse(base)
        if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise ValueError("base_url must be an HTTPS API URL")
    except Exception as exc:
        print("Input error: " + type(exc).__name__, file=sys.stderr)
        return 2

    cases, sessions, created = [], [], []
    now = lambda: dt.datetime.now(dt.timezone.utc).isoformat()
    son = nam = None
    try:
        selected = [next(a for a in accounts if a["alias"] == "son")]
        selected += [a for a in accounts if a["alias"] == "nam"]
        for account in selected:
            alias, device_id = account["alias"], "qa-academic-" + str(uuid.uuid4())
            status, body, error = request(base, "POST", "/auth/login", None, {
                "email": account["email"], "password": account["password"], "device_id": device_id,
                "platform": "ANDROID", "device_name": "QuizHub QA academic API probe",
                "os_version": "QA probe", "app_version": "QA probe",
            })
            data = body_data(body)
            token = data.get("access_token") if isinstance(data, dict) else None
            role = data.get("role") if isinstance(data, dict) else None
            record(cases, "ACA-AUTH-LOGIN-" + alias, "POST", "/auth/login", "success envelope and STUDENT role", status, body, error,
                   force="BLOCKED" if error else "PASS" if http.envelope_ok(status, body) and role == "STUDENT" and isinstance(token, str) else "FAIL",
                   identity_role=role if role in ("STUDENT", "LECTURER", "ADMIN") else None)
            if isinstance(token, str):
                session = {"alias": alias, "device_id": device_id, "token": token, "role": role}
                sessions.append(session)
                if http.envelope_ok(status, body) and role == "STUDENT":
                    if alias == "son": son = session
                    else: nam = session

        if son and son["role"] == "STUDENT":
            token = son["token"]
            status, body, error = request(base, "GET", "/sessions/my-enrolled-course-classes", token)
            enrolled = body_data(body)
            classes = safe_list(enrolled)
            eligible = [c for c in classes if isinstance(c, dict) and c.get("can_propose") is True
                        and isinstance(c.get("course_class_id", c.get("id")), int)]
            record(cases, "ACA-ENROLLED-CLASSES", "GET", "/sessions/my-enrolled-course-classes",
                   "2xx success envelope; inspect can_propose", status, body, error,
                   eligible_count=len(eligible), can_propose_available=bool(eligible))

            status, body, error = request(base, "GET", "/subjects", token)
            subjects = safe_list(body_data(body))
            subject_ids = {s.get("subject_id", s.get("id")) for s in subjects if isinstance(s, dict)}
            record(cases, "ACA-SUBJECTS", "GET", "/subjects", "2xx success envelope", status, body, error)

            status, body, error = request(base, "GET", "/sessions/my-submissions?limit=10", token)
            submission_data = body_data(body)
            submissions = safe_list(submission_data, "contents") or safe_list(submission_data, "items")
            record(cases, "ACA-MY-SUBMISSIONS", "GET", "/sessions/my-submissions",
                   "2xx success envelope; own submissions", status, body, error)

            status, body, error = request(base, "GET", "/lecturer/exams/my-exams", token)
            record(cases, "ACA-EXAMS-STUDENT-DENY", "GET", "/lecturer/exams/my-exams", "student is forbidden by qbank contract (403)",
                   status, body, error, force=reject_result(status))
            status, body, error = request(base, "GET", "/exams/my-exams", token)
            record(cases, "ACA-EXAMS-LEGACY-ROUTE", "GET", "/exams/my-exams",
                   "legacy app route; live contract route differs, classification WAITING",
                   status, body, error, force="BLOCKED" if error else "WAITING")

            chosen = eligible[0] if eligible else None
            class_id = chosen.get("course_class_id", chosen.get("id")) if chosen else None
            subject_exists = bool(chosen and chosen.get("subject_id") in subject_ids)
            eligible_for_proposal = bool(chosen and isinstance(class_id, int) and class_id > 0)
            if eligible_for_proposal:
                marker = uuid.uuid4().hex[:10]
                payload = proposal_payload(class_id, marker)
                status, body, error = request(base, "POST", "/sessions/propose", token, payload)
                proposal = body_data(body)
                session_id = proposal.get("session_id", proposal.get("id")) if isinstance(proposal, dict) else None
                record(cases, "ACA-PROPOSE-DISPOSABLE", "POST", "/sessions/propose",
                       "create unique three-question PENDING proposal", status, body, error,
                       question_count=len(payload["questions"]))
                if http.envelope_ok(status, body) and isinstance(session_id, int) and session_id > 0:
                    created.append({"session_id": session_id, "course_class_id": class_id, "marker": marker,
                                    "token": token, "deleted": False})
                    status, detail_body, detail_error = call_detail(base, token, session_id)
                    detail = body_data(detail_body)
                    matches, state, qcount = detail_state(detail, session_id, payload["title"])
                    detail_ok = http.envelope_ok(status, detail_body)
                    if not detail_ok:
                        matches, state, qcount = False, None, 0
                    pending_source = "detail"
                    pending_error = None
                    if detail_ok and state is None:
                        pstatus, pbody, pending_error, in_pending_list = confirm_pending_in_list(base, token, session_id)
                        state = "PENDING" if in_pending_list else None
                        pending_source = "status-filter"
                        record(cases, "ACA-PENDING-STATUS-FILTER", "GET", "/sessions/my-submissions",
                               "status=PENDING list contains created session", pstatus, pbody, pending_error,
                               force="BLOCKED" if pending_error else "PASS" if in_pending_list else "WAITING",
                               pending_list_contains_session=in_pending_list)
                    verified = detail_ok and matches and state == "PENDING" and qcount == 3
                    record(cases, "ACA-PROPOSAL-DETAIL", "GET", "/sessions/my-submissions/{sessionId}",
                           "created title, three questions, PENDING", status, detail_body, detail_error,
                           force="BLOCKED" if detail_error or pending_error else "PASS" if verified else "WAITING" if detail_ok and state is None else "FAIL",
                           title_matches=matches, pending=state == "PENDING", question_count=qcount,
                           pending_status_source=pending_source)

                    if state == "PENDING" and matches and qcount == 3:
                        if nam and nam.get("role") == "STUDENT":
                            status, body, error = request(base, "GET", f"/sessions/{session_id}/questions", nam["token"])
                            record(cases, "ACA-PENDING-PRACTICE-FORBIDDEN", "GET", "/sessions/{sessionId}/questions",
                                   "other student cannot access pending session (403)", status, body, error,
                                   force=reject_result(status))
                        else:
                            record(cases, "ACA-PENDING-PRACTICE-FORBIDDEN", "GET", "/sessions/{sessionId}/questions",
                                   "requires separate nam student account", None, None, force="WAITING")

                        updated_title = f"QA academic probe {marker} updated"
                        update = update_payload(class_id, marker, detail.get("questions", []))
                        valid_update = all(isinstance(q.get("question_id"), int) and isinstance(q.get("options"), list) and len(q["options"]) == 2
                                           for q in update["questions"])
                        if valid_update:
                            status, body, error = request(base, "PUT", f"/sessions/my-submissions/{session_id}", token, update)
                            record(cases, "ACA-UPDATE-DISPOSABLE", "PUT", "/sessions/my-submissions/{sessionId}",
                                   "rename only own pending QA proposal and preserve all three questions", status, body, error,
                                   sent_question_count=len(update["questions"]))
                            status, verify_body, verify_error = call_detail(base, token, session_id)
                            verify = body_data(verify_body)
                            matches, state, qcount = detail_state(verify, session_id, updated_title)
                            verify_ok = http.envelope_ok(status, verify_body)
                            if not verify_ok:
                                matches, state, qcount = False, None, 0
                            verify_pending_error = None
                            if verify_ok and state is None:
                                pstatus, pbody, verify_pending_error, in_pending_list = confirm_pending_in_list(base, token, session_id)
                                state = "PENDING" if in_pending_list else None
                                record(cases, "ACA-UPDATE-PENDING-FILTER", "GET", "/sessions/my-submissions",
                                       "status=PENDING list contains updated session", pstatus, pbody, verify_pending_error,
                                       force="BLOCKED" if verify_pending_error else "PASS" if in_pending_list else "WAITING",
                                       pending_list_contains_session=in_pending_list)
                            record(cases, "ACA-UPDATE-VERIFY", "GET", "/sessions/my-submissions/{sessionId}",
                                   "updated title and same three questions remain PENDING", status, verify_body, verify_error,
                                   force="BLOCKED" if verify_error or verify_pending_error else "PASS" if verify_ok and matches and state == "PENDING" and qcount == 3 else "WAITING" if verify_ok and state is None else "FAIL",
                                   title_matches=matches, pending=state == "PENDING", question_count=qcount)
                        else:
                            record(cases, "ACA-UPDATE-DISPOSABLE", "PUT", "/sessions/my-submissions/{sessionId}",
                                   "update requires three returned question IDs and options", None, None, force="BLOCKED",
                                   sent_question_count=len(update["questions"]))

                        # Delete only after a fresh read still confirms this disposable proposal is PENDING.
                        status, latest_body, latest_error = call_detail(base, token, session_id)
                        latest = body_data(latest_body)
                        _, latest_state, _ = detail_state(latest, session_id)
                        latest_ok = http.envelope_ok(status, latest_body)
                        if not latest_ok:
                            latest_state = None
                        latest_pending_error = None
                        if status == 404:
                            created[-1]["deleted"] = True
                            record(cases, "ACA-DELETE-VERIFY", "GET", "/sessions/my-submissions/{sessionId}",
                                   "created proposal is already absent (404)", status, latest_body, latest_error,
                                   force="PASS")
                        elif latest_ok and latest_state is None:
                            pstatus, pbody, latest_pending_error, in_pending_list = confirm_pending_in_list(base, token, session_id)
                            latest_state = "PENDING" if in_pending_list else None
                            record(cases, "ACA-DELETE-PENDING-FILTER", "GET", "/sessions/my-submissions",
                                   "status=PENDING list contains created session", pstatus, pbody, latest_pending_error,
                                   force="BLOCKED" if latest_pending_error else "PASS" if in_pending_list else "WAITING",
                                   pending_list_contains_session=in_pending_list)
                        if created[-1]["deleted"]:
                            pass
                        elif latest_error or latest_pending_error or not latest_ok:
                            record(cases, "ACA-DELETE-DISPOSABLE", "DELETE", "/sessions/my-submissions/{sessionId}",
                                   "delete only while PENDING", status, latest_body, latest_error or latest_pending_error, force="BLOCKED")
                        elif latest_state == "PENDING":
                            status, body, error = request(base, "DELETE", f"/sessions/my-submissions/{session_id}", token)
                            record(cases, "ACA-DELETE-DISPOSABLE", "DELETE", "/sessions/my-submissions/{sessionId}",
                                   "delete only the created PENDING proposal", status, body, error)
                            if http.envelope_ok(status, body):
                                status, verify_body, verify_error = call_detail(base, token, session_id)
                                created[-1]["deleted"] = status == 404
                                record(cases, "ACA-DELETE-VERIFY", "GET", "/sessions/my-submissions/{sessionId}",
                                       "deleted proposal is absent (404)", status, verify_body, verify_error,
                                       force="BLOCKED" if verify_error else "PASS" if status == 404 else "FAIL")
                        else:
                            record(cases, "ACA-DELETE-DISPOSABLE", "DELETE", "/sessions/my-submissions/{sessionId}",
                                   "do not delete after review starts", status, latest_body, latest_error,
                                   force="BLOCKED")
                    else:
                        for case_id, method in (("ACA-UPDATE-DISPOSABLE", "PUT"), ("ACA-DELETE-DISPOSABLE", "DELETE")):
                            record(cases, case_id, method, "/sessions/my-submissions/{sessionId}",
                                   "requires verified PENDING disposable proposal", None, None, force="BLOCKED")
                else:
                    if http.envelope_ok(status, body):
                        record(cases, "ACA-PROPOSAL-ID", "POST", "/sessions/propose",
                               "successful create must return session ID for safe cleanup", status, body, error,
                               force="BLOCKED")
                    for case_id, method in (("ACA-UPDATE-DISPOSABLE", "PUT"), ("ACA-DELETE-DISPOSABLE", "DELETE")):
                        record(cases, case_id, method, "/sessions/my-submissions/{sessionId}",
                               "requires successfully created disposable proposal", None, None, force="BLOCKED")
            else:
                for case_id, method in (("ACA-PROPOSE-DISPOSABLE", "POST"), ("ACA-UPDATE-DISPOSABLE", "PUT"),
                                        ("ACA-DELETE-DISPOSABLE", "DELETE")):
                    record(cases, case_id, method, "/sessions/propose" if method == "POST" else "/sessions/my-submissions/{sessionId}",
                           "requires an enrolled course class with can_propose=true", None, None, force="BLOCKED",
                           can_propose_available=bool(eligible), subject_exists=subject_exists)

            # Read-only coverage for one explicitly RESOLVED session owned by Son, if status is present.
            resolved = next((s for s in submissions if isinstance(s, dict) and s.get("status") == "RESOLVED"
                             and isinstance(s.get("session_id", s.get("id")), int)), None)
            if resolved:
                sid = resolved.get("session_id", resolved.get("id"))
                status, detail_body, error = call_detail(base, token, sid)
                detail = body_data(detail_body)
                is_resolved = http.envelope_ok(status, detail_body) and isinstance(detail, dict) and detail.get("status") == "RESOLVED"
                record(cases, "ACA-OWN-RESOLVED-DETAIL", "GET", "/sessions/my-submissions/{sessionId}",
                       "own detail confirms RESOLVED", status, detail_body, error,
                       force="BLOCKED" if error else "PASS" if is_resolved else "WAITING" if http.envelope_ok(status, detail_body) and isinstance(detail, dict) and detail.get("status") is None else "FAIL",
                       resolved=is_resolved)
                if is_resolved:
                    status, practice_body, error = request(base, "GET", f"/sessions/{sid}/questions", token)
                    practice = body_data(practice_body)
                    questions = safe_list(practice, "questions")
                    record(cases, "ACA-OWN-RESOLVED-PRACTICE", "GET", "/sessions/{sessionId}/questions",
                           "read own resolved session; no answers or ratings submitted", status, practice_body, error)
                    q = next((q for q in questions if isinstance(q, dict) and isinstance(q.get("question_id", q.get("id")), int)), None)
                    if q:
                        qid = q.get("question_id", q.get("id"))
                        for suffix, route in (("STATS", "statistics"), ("RATINGS", "ratings")):
                            path = f"/questions/{qid}/{route}" + ("?limit=10" if route == "ratings" else "")
                            status, body, error = request(base, "GET", path, token)
                            record(cases, "ACA-OWN-RESOLVED-" + suffix, "GET", f"/questions/{{questionId}}/{route}",
                                   "read-only question metadata", status, body, error)
                    else:
                        for suffix, route in (("STATS", "statistics"), ("RATINGS", "ratings")):
                            record(cases, "ACA-OWN-RESOLVED-" + suffix, "GET", f"/questions/{{questionId}}/{route}",
                                   "requires a question ID from own resolved session", None, None, force="WAITING")
            else:
                record(cases, "ACA-OWN-RESOLVED-DETAIL", "GET", "/sessions/my-submissions/{sessionId}",
                       "requires own list item with explicit RESOLVED status", None, None, force="WAITING")
                record(cases, "ACA-OWN-RESOLVED-PRACTICE", "GET", "/sessions/{sessionId}/questions",
                       "requires own verified RESOLVED session", None, None, force="WAITING")
                for suffix, route in (("STATS", "statistics"), ("RATINGS", "ratings")):
                    record(cases, "ACA-OWN-RESOLVED-" + suffix, "GET", f"/questions/{{questionId}}/{route}",
                           "requires question ID from own resolved session", None, None, force="WAITING")
        else:
            record(cases, "ACA-STUDENT-SCOPE", "GET", "/sessions/my-enrolled-course-classes", "requires a Student login", None, None, force="BLOCKED")
    finally:
        try:
            for item in created:
                if item["deleted"]:
                    continue
                status, body, error = call_detail(base, item["token"], item["session_id"])
                detail = body_data(body)
                _, state, _ = detail_state(detail, item["session_id"])
                detail_ok = http.envelope_ok(status, body)
                if not detail_ok:
                    state = None
                if status == 404:
                    record(cases, "ACA-CLEANUP-ABSENT", "GET", "/sessions/my-submissions/{sessionId}",
                           "created proposal is already absent", status, body, error, force="PASS")
                elif state is None and detail_ok:
                    pstatus, pbody, pending_error, in_pending_list = confirm_pending_in_list(base, item["token"], item["session_id"])
                    state = "PENDING" if in_pending_list else None
                    record(cases, "ACA-CLEANUP-PENDING-FILTER", "GET", "/sessions/my-submissions",
                           "status=PENDING list contains created session", pstatus, pbody, pending_error,
                           force="BLOCKED" if pending_error else "PASS" if in_pending_list else "WAITING",
                           pending_list_contains_session=in_pending_list)
                    if pending_error:
                        error = pending_error
                if status == 404:
                    item["deleted"] = True
                    record(cases, "ACA-CLEANUP-ABSENT", "GET", "/sessions/my-submissions/{sessionId}",
                           "created proposal is absent", status, body, error, force="PASS")
                elif error or not detail_ok or state != "PENDING":
                    record(cases, "ACA-CLEANUP", "DELETE", "/sessions/my-submissions/{sessionId}",
                           "delete only while still PENDING", status, body, error, force="BLOCKED")
                else:
                    status, body, error = request(base, "DELETE", f"/sessions/my-submissions/{item['session_id']}", item["token"])
                    record(cases, "ACA-CLEANUP", "DELETE", "/sessions/my-submissions/{sessionId}",
                           "delete created PENDING proposal in finally", status, body, error)
                    if http.envelope_ok(status, body):
                        status, body, error = call_detail(base, item["token"], item["session_id"])
                        item["deleted"] = status == 404
                        record(cases, "ACA-CLEANUP-VERIFY", "GET", "/sessions/my-submissions/{sessionId}",
                               "finally cleanup leaves proposal absent (404)", status, body, error,
                               force="BLOCKED" if error else "PASS" if status == 404 else "FAIL")
        finally:
            for session in sessions:
                status, body, error = request(base, "POST", "/auth/logout", session["token"])
                record(cases, "ACA-AUTH-LOGOUT-" + session["alias"], "POST", "/auth/logout",
                       "logout generated QA device session", status, body, error)

    report = {
        "phase": "real-academic-smoke", "classification": "real API smoke; not whole acceptance",
        "timestamp_utc": now(), "tested_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
        "api_host": urllib.parse.urlparse(base).hostname, "accounts": [a["alias"] for a in selected], "cases": cases,
    }
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"cases": len(cases), "output": args.output,
                      "counts": {s: sum(c["status"] == s for c in cases) for s in ("PASS", "FAIL", "BLOCKED", "WAITING")}}))
    auth_blocker = any(c["case_id"].startswith("ACA-AUTH-LOGIN-") and c["http_status"] in (401, 403) for c in cases)
    transport_blocker = any("transport_error" in c.get("observed", {}) for c in cases)
    cleanup_blocker = any(c["case_id"].startswith(("ACA-CLEANUP", "ACA-PROPOSAL-ID")) and c["status"] == "BLOCKED" for c in cases)
    return 2 if not son or auth_blocker or transport_blocker or cleanup_blocker else 0


if __name__ == "__main__":
    sys.exit(main())
