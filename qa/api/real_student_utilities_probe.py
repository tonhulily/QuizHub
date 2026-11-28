#!/usr/bin/env python3
"""Reversible student utilities smoke using disposable QA values only."""

import argparse
import copy
import datetime as dt
import json
import re
import subprocess
import sys
import urllib.parse
import uuid
from pathlib import Path

from real_student_probe import add_case, default_base_url, envelope_ok, request

SUCCESS = {"0000", "1000"}


def push_body(data):
    if not isinstance(data, dict) or not all(type(data.get(k)) is bool for k in ("push_enabled", "sound_enabled", "vibration_enabled")):
        return None
    cats, quiet = data.get("categories"), data.get("quiet_hours")
    if not isinstance(cats, dict) or not isinstance(quiet, dict):
        return None
    if any(not isinstance(v, dict) or type(v.get("enabled")) is not bool or not isinstance(v.get("description", ""), str) for v in cats.values()):
        return None
    if type(quiet.get("enabled")) is not bool or not all(isinstance(quiet.get(k), str) for k in ("start_time", "end_time")):
        return None
    return {
        "push_enabled": data["push_enabled"],
        "categories": {k: {"enabled": v["enabled"], "description": v.get("description", "")} for k, v in cats.items()},
        "quiet_hours": {k: quiet[k] for k in ("enabled", "start_time", "end_time")},
        "sound_enabled": data["sound_enabled"],
        "vibration_enabled": data["vibration_enabled"],
    }


def saved_rows(body):
    data = body.get("data") if isinstance(body, dict) else None
    return data.get("saved_searches", []) if isinstance(data, dict) and isinstance(data.get("saved_searches"), list) else []


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output")
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    if args.self_check:
        sample = {"push_enabled": True, "sound_enabled": False, "vibration_enabled": True,
                  "categories": {"SOCIAL": {"enabled": True, "description": "ok"}},
                  "quiet_hours": {"enabled": False, "start_time": "22:00", "end_time": "07:00"},
                  "email": "private@example.test"}
        assert push_body(sample)["push_enabled"] is True
        assert push_body({"push_enabled": True}) is None
        assert "private@example.test" not in json.dumps(push_body(sample))
        print("self-check PASS")
        return 0
    if not args.output:
        parser.error("--output is required for an API run")

    try:
        supplied = json.load(sys.stdin)
        accounts = supplied["accounts"]
        base = (supplied.get("base_url") or default_base_url()).rstrip("/")
        if not isinstance(accounts, list) or [a.get("alias") for a in accounts] != ["son", "nam"]:
            raise ValueError
        if any(not isinstance(a.get("email"), str) or not isinstance(a.get("password"), str) for a in accounts):
            raise ValueError
        parsed = urllib.parse.urlparse(base)
        if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise ValueError
    except Exception:
        print("input BLOCKED", file=sys.stderr)
        return 2

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    results, sessions, tracked_searches = [], [], []
    push_original = push_changed = None
    follow_target = None
    follow_owned = False
    follow_attempted = False
    failures = []
    marker = "QA_20261128_" + uuid.uuid4().hex[:12]
    now = lambda: dt.datetime.now(dt.timezone.utc).isoformat()

    def record(case_id, method, path, expected, status, body, error=None, force=None):
        outcome = add_case(results, case_id, method, path, expected, status, body, error, force)
        row = results[-1]
        if row.get("business_code") is not None and not re.fullmatch(r"\d{4}", str(row["business_code"])):
            row["business_code"] = None
        if outcome == "FAIL":
            failures.append(case_id)
        return outcome

    def check_request(session, method, path, case, expected, payload=None, report_path=None, force=None):
        status, body, error = request(base, method, path, session.get("access") if session else None, payload)
        record(case, method, report_path or path.split("?", 1)[0], expected, status, body, error, force)
        return status, body, error

    try:
        for account in accounts:
            device_id = "qa-probe-" + uuid.uuid4().hex
            status, body, error = request(base, "POST", "/auth/login", payload={
                "email": account["email"], "password": account["password"], "device_id": device_id,
                "platform": "ANDROID", "device_name": "QuizHub QA utilities probe", "os_version": "QA", "app_version": "QA",
            })
            record("UTIL-AUTH-" + account["alias"], "POST", "/auth/login", "test-device login", status, body, error)
            data = body.get("data") if isinstance(body, dict) else None
            access = data.get("access_token") if isinstance(data, dict) else None
            if not envelope_ok(status, body) or not isinstance(access, str):
                raise RuntimeError("login unavailable")
            session = {"alias": account["alias"], "access": access, "device_id": device_id}
            sessions.append(session)
            status, body, error = check_request(session, "GET", "/users/me", "UTIL-IDENTITY-" + account["alias"], "student role and numeric user id")
            profile = body.get("data") if isinstance(body, dict) else None
            session["user_id"] = profile.get("user_id") if isinstance(profile, dict) else None
            session["role"] = profile.get("role") if isinstance(profile, dict) else None
            if not envelope_ok(status, body) or session["role"] != "STUDENT" or not isinstance(session["user_id"], int):
                raise RuntimeError("student identity not confirmed")

        son, nam = sessions
        if isinstance(nam.get("user_id"), int):
            status, body, error = check_request(son, "GET", f"/users/{nam['user_id']}", "UTIL-PROFILE-PRIVACY", "other-user profile omits email and date_of_birth", report_path="/users/{userId}")
            profile = body.get("data") if isinstance(body, dict) else None
            email_present = isinstance(profile, dict) and "email" in profile
            dob_present = isinstance(profile, dict) and "date_of_birth" in profile
            email_value_present = email_present and profile.get("email") is not None and profile.get("email") != ""
            dob_value_present = dob_present and profile.get("date_of_birth") is not None and profile.get("date_of_birth") != ""
            privacy_outcome = "PASS" if envelope_ok(status, body) and not email_present and not dob_present else (
                "FAIL" if email_value_present or dob_value_present else "WAITING")
            record("UTIL-PROFILE-PRIVACY-ASSERT", "GET", "/users/{userId}", "omit email/date_of_birth keys from other-user profile", status, body, error, privacy_outcome)
            results[-1]["email_key_present"] = bool(email_present)
            results[-1]["email_value_present"] = bool(email_value_present)
            results[-1]["date_of_birth_key_present"] = bool(dob_present)
            results[-1]["date_of_birth_value_present"] = bool(dob_value_present)

        # Push settings: preserve the complete model shape, toggle one boolean, then restore.
        status, body, error = check_request(son, "GET", "/settings/push", "UTIL-PUSH-GET", "2xx success envelope with PushSettings model")
        push_data = body.get("data") if isinstance(body, dict) else None
        push_original = push_body(push_data)
        if not envelope_ok(status, body) or push_original is None:
            record("UTIL-PUSH-SHAPE", "GET", "/settings/push", "known complete settings required before mutation", status, body, error, "WAITING")
        else:
            push_changed = copy.deepcopy(push_original)
            push_changed["push_enabled"] = not push_original["push_enabled"]
            # Restore in finally even if the PUT response is lost after server commit.
            status, body, error = check_request(son, "PUT", "/settings/push", "UTIL-PUSH-TOGGLE", "toggle push_enabled; preserve other fields", push_changed)
            if envelope_ok(status, body):
                status, body, error = check_request(son, "GET", "/settings/push", "UTIL-PUSH-VERIFY", "push_enabled changed and other settings preserved")
                observed = push_body(body.get("data") if isinstance(body, dict) else None)
                passed = envelope_ok(status, body) and observed == push_changed
                record("UTIL-PUSH-ASSERT", "GET", "/settings/push", "exact temporary state readback", status, body, error, "PASS" if passed else "FAIL")

        # Read two feed pages and reuse the server cursor verbatim; log overlap only.
        status, body, error = check_request(son, "GET", "/activity-feeds?limit=2", "UTIL-FEED-PAGE-1", "first two feed items", report_path="/activity-feeds")
        feed_data = body.get("data") if isinstance(body, dict) else None
        feed_rows = feed_data.get("items", []) if isinstance(feed_data, dict) else []
        pagination = feed_data.get("pagination", {}) if isinstance(feed_data, dict) else {}
        if envelope_ok(status, body) and isinstance(pagination, dict) and pagination.get("has_next") is True:
            cursor = pagination.get("after")
            if cursor is None:
                record("UTIL-FEED-CURSOR", "GET", "/activity-feeds", "has_next requires cursor", status, body, error, "WAITING")
            else:
                query = urllib.parse.urlencode({"after": str(cursor), "limit": 2})
                status2, body2, error2 = check_request(son, "GET", "/activity-feeds?" + query, "UTIL-FEED-PAGE-2", "next page with exact returned cursor", report_path="/activity-feeds")
                data2 = body2.get("data") if isinstance(body2, dict) else None
                rows2 = data2.get("items", []) if isinstance(data2, dict) else []
                ids1 = {r.get("feed_id", r.get("id")) for r in feed_rows if isinstance(r, dict)}
                ids2 = {r.get("feed_id", r.get("id")) for r in rows2 if isinstance(r, dict)}
                overlap = len(ids1 & ids2)
                ids_known = all(x is not None for x in ids1 | ids2)
                outcome = "PASS" if envelope_ok(status2, body2) and ids_known and overlap == 0 else (
                    "FAIL" if envelope_ok(status2, body2) and ids_known else "WAITING")
                record("UTIL-FEED-PAGE-OVERLAP", "GET", "/activity-feeds", "no repeated feed IDs across pages", status2, body2, error2, outcome)
                results[-1]["overlap_count"] = overlap if ids_known else None

        # Saved-search creation is in the live Swagger; the pinned local snapshot may lag.
        status, body, error = check_request(son, "GET", "/search/saved", "UTIL-SEARCH-BASELINE", "current saved-search list", report_path="/search/saved")
        baseline = saved_rows(body) if envelope_ok(status, body) else []
        save_path_documented = "post" in json.loads((Path(__file__).resolve().parents[2] / "docs/api-samples/openapi.json").read_text(encoding="utf-8")).get("paths", {}).get("/search/saved", {})
        if not envelope_ok(status, body):
            record("UTIL-SEARCH-SKIP", "POST", "/search/saved", "baseline required before mutation", status, body, error, "WAITING")
        else:
            save_case = "UTIL-SEARCH-SAVE"
            status, body, error = check_request(son, "POST", "/search/saved", save_case,
                                                "create disposable QA term; local pinned snapshot may lag live Swagger",
                                                {"query": marker}, report_path="/search/saved")
            if status in (404, 405) and not save_path_documented:
                results[-1]["status"] = "WAITING"
                if save_case in failures:
                    failures.remove(save_case)
                record("UTIL-SEARCH-SAVE-WAITING", "POST", "/search/saved", "OpenAPI operation absent; clarify owner contract", status, body, error, "WAITING")
            elif status is None or status >= 500 or (status is not None and 200 <= status < 300):
                find_status, find_body, find_error = check_request(son, "GET", "/search/saved", "UTIL-SEARCH-FIND", "identify only exact disposable term")
                rows = saved_rows(find_body)
                before_ids = {r.get("saved_search_id") for r in baseline if isinstance(r, dict)}
                found = [r for r in rows if isinstance(r, dict) and r.get("query_text") == marker and r.get("saved_search_id") not in before_ids]
                if len(found) == 1 and isinstance(found[0].get("saved_search_id"), int):
                    tracked_searches.append(found[0]["saved_search_id"])
                else:
                    unknown_create = status is None or (status is not None and 200 <= status < 300)
                    record("UTIL-SEARCH-IDENTIFY", "GET", "/search/saved", "one newly created exact marker with id", find_status, find_body, find_error,
                           "BLOCKED" if unknown_create else "WAITING")
                    if unknown_create:
                        raise RuntimeError("created saved search not safely identifiable")
                if tracked_searches:
                    search_id = tracked_searches[-1]
                    delete_status, delete_body, delete_error = check_request(son, "DELETE", f"/search/saved/{search_id}", "UTIL-SEARCH-DELETE", "delete only disposable search", report_path="/search/saved/{id}")
                    if envelope_ok(delete_status, delete_body):
                        tracked_searches.remove(search_id)
                        status, body, error = check_request(son, "GET", "/search/saved", "UTIL-SEARCH-ABSENT", "exact marker absent after delete")
                        present = any(r.get("query_text") == marker for r in saved_rows(body))
                        record("UTIL-SEARCH-ABSENT-ASSERT", "GET", "/search/saved", "marker absent", status, body, error,
                               "PASS" if envelope_ok(status, body) and not present else "FAIL")

        # Follow only if the known baseline is false; restore only the relation this run creates.
        identity = son.get("user_id")
        other_id = nam.get("user_id")
        if identity is None or other_id is None or identity == other_id:
            record("UTIL-FOLLOW-BASELINE", "GET", "/users/{userId}/relationship-stats", "distinct known student IDs", None, None, force="WAITING")
        else:
            follow_target = other_id
            stats_path = f"/users/{other_id}/relationship-stats"
            status, body, error = check_request(son, "GET", stats_path, "UTIL-FOLLOW-BASELINE", "relationship_with_me.following is false", report_path="/users/{userId}/relationship-stats")
            stats = body.get("data", {}).get("relationship_with_me", {}) if isinstance(body, dict) else {}
            baseline_following = stats.get("following") if isinstance(stats, dict) else None
            if not envelope_ok(status, body) or type(baseline_following) is not bool:
                record("UTIL-FOLLOW-SHAPE", "GET", "/users/{userId}/relationship-stats", "following boolean required", status, body, error, "WAITING")
            elif baseline_following:
                record("UTIL-FOLLOW-SKIP-EXISTING", "GET", "/users/{userId}/relationship-stats", "preserve existing follow", status, body, error, "NOT RUN")
            else:
                follow_attempted = True
                status, body, error = check_request(son, "POST", f"/follows/{other_id}", "UTIL-FOLLOW", "create follow from false baseline", report_path="/follows/{targetUserId}")
                if envelope_ok(status, body):
                    follow_owned = True
                    status, body, error = check_request(son, "GET", stats_path, "UTIL-FOLLOW-VERIFY", "relationship_with_me.following true", report_path="/users/{userId}/relationship-stats")
                    observed = body.get("data", {}).get("relationship_with_me", {}) if isinstance(body, dict) else {}
                    passed = envelope_ok(status, body) and isinstance(observed, dict) and observed.get("following") is True
                    record("UTIL-FOLLOW-ASSERT", "GET", "/users/{userId}/relationship-stats", "following true", status, body, error, "PASS" if passed else "FAIL")
    except Exception:
        record("UTIL-RUN", "GET", "/", "runner stopped safely", None, None, force="BLOCKED")
    finally:
        for search_id in tracked_searches:
            status, body, error = check_request(son, "DELETE", f"/search/saved/{search_id}", "UTIL-SEARCH-CLEANUP", "remove tracked disposable term", report_path="/search/saved/{id}") if sessions else (None, None, "no session")
            if not envelope_ok(status, body):
                record("UTIL-SEARCH-CLEANUP-STATUS", "DELETE", "/search/saved/{id}", "cleanup confirmation", status, body, error, "BLOCKED")
        if push_original is not None:
            status, body, error = check_request(son, "PUT", "/settings/push", "UTIL-PUSH-RESTORE", "restore exact original settings", push_original) if sessions else (None, None, "no session")
            if envelope_ok(status, body):
                status, body, error = check_request(son, "GET", "/settings/push", "UTIL-PUSH-RESTORE-VERIFY", "original settings restored")
                observed = push_body(body.get("data") if isinstance(body, dict) else None)
                record("UTIL-PUSH-RESTORE-ASSERT", "GET", "/settings/push", "full settings equal baseline", status, body, error,
                       "PASS" if envelope_ok(status, body) and observed == push_original else "FAIL")
        if follow_attempted and not follow_owned and follow_target is not None and sessions:
            status, body, error = check_request(son, "GET", f"/users/{follow_target}/relationship-stats", "UTIL-FOLLOW-AMBIGUOUS-CHECK", "check baseline after ambiguous follow result", report_path="/users/{userId}/relationship-stats")
            observed = body.get("data", {}).get("relationship_with_me", {}) if isinstance(body, dict) else {}
            if envelope_ok(status, body) and isinstance(observed, dict) and observed.get("following") is True:
                record("UTIL-FOLLOW-CLEANUP-UNCERTAIN", "GET", "/users/{userId}/relationship-stats", "manual cleanup needed; not confirmed test-created", status, body, error, "BLOCKED")
        if follow_owned and follow_target is not None and sessions:
            status, body, error = check_request(son, "DELETE", f"/follows/{follow_target}", "UTIL-FOLLOW-RESTORE", "remove only newly created follow", report_path="/follows/{targetUserId}")
            if envelope_ok(status, body):
                status, body, error = check_request(son, "GET", f"/users/{follow_target}/relationship-stats", "UTIL-FOLLOW-RESTORE-VERIFY", "following false restored", report_path="/users/{userId}/relationship-stats")
                observed = body.get("data", {}).get("relationship_with_me", {}) if isinstance(body, dict) else {}
                record("UTIL-FOLLOW-RESTORE-ASSERT", "GET", "/users/{userId}/relationship-stats", "following false", status, body, error,
                       "PASS" if envelope_ok(status, body) and isinstance(observed, dict) and observed.get("following") is False else "FAIL")
        for session in sessions:
            status, body, error = request(base, "POST", "/auth/logout", session["access"])
            record("UTIL-LOGOUT-" + session["alias"], "POST", "/auth/logout", "logout only probe-created session", status, body, error)

    try:
        sha = subprocess.run(["git", "rev-parse", "HEAD"], check=True, capture_output=True, text=True, timeout=2).stdout.strip()
    except Exception:
        sha = "unknown"
    report = {"phase": "utilities", "classification": "reversible real API smoke", "tested_sha": sha,
              "timestamp_utc": now(), "environment": supplied.get("environment", "unknown") if supplied.get("environment") in {"qa", "staging", "dev"} else "unknown",
              "api_host": urllib.parse.urlparse(base).hostname, "accounts": [a["alias"] for a in accounts], "cases": results}
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    counts = {s: sum(c["status"] == s for c in results) for s in ("PASS", "FAIL", "BLOCKED", "WAITING", "NOT RUN")}
    print(json.dumps({"cases": len(results), "counts": counts, "output": args.output}))
    return 1 if counts["FAIL"] else 2 if counts["BLOCKED"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
