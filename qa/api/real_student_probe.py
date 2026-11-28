#!/usr/bin/env python3
"""Read-only student API baseline; credentials are accepted only through stdin."""
import argparse
import datetime as dt
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

OPENAPI = Path(__file__).resolve().parents[2] / "docs/api-samples/openapi.json"
APP_CONFIG = Path(__file__).resolve().parents[2] / "lib/core/config/app_config.dart"
TIMEOUT = 15
MAX_BODY = 2 * 1024 * 1024


def default_base_url():
    source = APP_CONFIG.read_text(encoding="utf-8")
    match = re.search(r"defaultValue:\s*'([^']+)'", source)
    if not match:
        raise ValueError("AppConfig API default unavailable")
    return match.group(1).rstrip("/")


def shape(value):
    if isinstance(value, dict):
        return {"type": "object", "keys": sorted(str(k) for k in value)[:40]}
    if isinstance(value, list):
        return {"type": "array", "count": len(value), "item_type": type(value[0]).__name__ if value else None}
    return {"type": type(value).__name__}


def safe_message(value):
    if not isinstance(value, str):
        return {"type": type(value).__name__}
    return {"type": "string", "length": len(value)}


def safe_code(value):
    return str(value) if isinstance(value, (str, int, float, bool)) and re.fullmatch(r"[A-Za-z0-9_.-]{1,32}", str(value)) else None


def envelope_ok(status, body):
    return status is not None and 200 <= status < 300 and isinstance(body, dict) and str(body.get("code")) in ("0000", "1000")


def denial_result(status):
    return "BLOCKED" if status is None else "PASS" if status in (401, 403) else "FAIL"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


OPENER = urllib.request.build_opener(NoRedirect())


def request(base, method, path, token=None, payload=None):
    url = base.rstrip("/") + path
    headers = {"Accept": "application/json"}
    data = None
    if token:
        headers["Authorization"] = "Bearer " + token
    if payload is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with OPENER.open(req, timeout=TIMEOUT) as response:
            status, raw = response.status, response.read(MAX_BODY + 1)
    except urllib.error.HTTPError as exc:
        status, raw = exc.code, exc.read(MAX_BODY + 1)
    except Exception as exc:
        return None, None, {"type": type(exc).__name__}
    if len(raw) > MAX_BODY:
        return status, None, {"type": "response_too_large", "limit": MAX_BODY}
    try:
        body = json.loads(raw) if raw else None
    except (ValueError, UnicodeDecodeError):
        body = None
    return status, body, None


def response_summary(body):
    if not isinstance(body, dict):
        return {"shape": shape(body)}
    summary = {"shape": shape(body)}
    if "code" in body:
        summary["business_code"] = safe_code(body["code"])
    if "message" in body:
        summary["message"] = safe_message(body["message"])
    if "data" in body:
        data = body["data"]
        summary["data"] = shape(data)
        if isinstance(data, list):
            summary["count"] = len(data)
        elif isinstance(data, dict):
            for k in ("items", "content", "results"):
                if isinstance(data.get(k), list):
                    summary["count"] = len(data[k])
                    break
    return summary


def add_case(results, case_id, method, path, expected, status, body, error=None, force=None):
    passed = envelope_ok(status, body)
    outcome = force or ("PASS" if passed else "FAIL" if status is not None else "BLOCKED")
    results.append({
        "case_id": case_id, "method": method, "path": path.split("?", 1)[0],
        "status": outcome, "http_status": status, "business_code": safe_code(body.get("code")) if isinstance(body, dict) else None,
        "expected": expected, "observed": response_summary(body) if error is None else {"transport_error": error},
        "timestamp_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
    })
    query = urllib.parse.parse_qs(urllib.parse.urlsplit(path).query)
    if query:
        results[-1]["query_params"] = {k: v[0] for k, v in query.items() if k in {"type", "limit", "sort_by", "only_unlocked", "query"}}
    return outcome


def contract_gets(spec):
    # These paths are the app's student-facing GET surface; mutation methods are excluded.
    exact = {
        "/subjects", "/sessions/my-submissions",
        "/posts/me", "/activity-feeds", "/friendships",
        "/friendships/requests/received", "/friendships/requests/sent", "/follows/followers",
        "/follows/following", "/blocks", "/conversations", "/notifications",
        "/settings/push", "/games/my-predictions", "/games/leaderboard", "/badges/me",
        "/cosmetics/shop", "/cosmetics/my-inventory", "/devices", "/search/saved",
    }
    # General search supports user, question bank and submission summaries without exposing a query.
    paths = []
    for path, methods in spec.get("paths", {}).items():
        if "get" not in methods:
            continue
        if path in exact or path == "/search":
            paths.append((path, methods["get"]))
    return paths


def query_for(operation, search_type=None):
    query = {}
    for param in operation.get("parameters", []):
        if param.get("in") != "query":
            continue
        name, schema = param["name"], param.get("schema", {})
        if name == "query":
            query[name] = "QA"  # Fixed nonpersonal probe term.
        elif name == "type" and search_type:
            query[name] = search_type
        elif "default" in schema:
            query[name] = schema["default"]
        elif schema.get("enum"):
            query[name] = schema["enum"][0]
    if search_type and not any(p["name"] == "type" for p in operation.get("parameters", [])):
        query["type"] = search_type
    return "?" + urllib.parse.urlencode(query) if query else ""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=["baseline"], required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    if args.self_check:
        sample = {"email": "private@example.test", "token": "secret", "message": "private@example.test secret"}
        safe = {"shape": shape(sample), "message": safe_message(sample["message"])}
        assert "private@example.test" not in json.dumps(safe) and "secret" not in json.dumps(safe)
        assert safe["shape"]["keys"] == ["email", "message", "token"] and safe["message"]["length"] == len(sample["message"])
        assert add_case([], "NEGATIVE-CHECK", "GET", "/users/me", "must reject", 200, {"code": "0000"}, force=denial_result(200)) == "FAIL"
        assert add_case([], "SUCCESS-CHECK", "GET", "/users/me", "success envelope", 200, {"code": "1000"}) == "PASS"
        assert denial_result(403) == "PASS" and denial_result(None) == "BLOCKED"
        print("self-check PASS")
        return 0

    # Read once; never echo input or retain it in evidence.
    try:
        supplied = json.load(sys.stdin)
        accounts = supplied["accounts"]
        base = (supplied.get("base_url") or default_base_url()).rstrip("/")
        if not isinstance(accounts, list) or not accounts or any(
            not isinstance(a, dict) or not all(k in a for k in ("alias", "email", "password"))
            or not re.fullmatch(r"[A-Za-z0-9_-]{1,32}", str(a["alias"]))
            or not isinstance(a["email"], str) or not isinstance(a["password"], str) for a in accounts
        ):
            raise ValueError("expected accounts with alias, email and password")
        parsed = urllib.parse.urlparse(base)
        if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise ValueError("base_url must be an HTTPS API URL")
    except Exception as exc:
        print("Input error: " + type(exc).__name__, file=sys.stderr)
        return 2

    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    results, sessions = [], []
    broad_done = False
    now = lambda: dt.datetime.now(dt.timezone.utc).isoformat()
    try:
        for account in accounts:
            alias = str(account["alias"])
            device_id = "qa-probe-" + str(uuid.uuid4())
            status, body, error = request(base, "POST", "/auth/login", payload={
                "email": account["email"], "password": account["password"], "device_id": device_id,
                "platform": "ANDROID", "device_name": "QuizHub QA API probe", "os_version": "QA probe", "app_version": "QA probe",
            })
            add_case(results, "AUTH-LOGIN-" + alias, "POST", "/auth/login", "OpenAPI 2xx login; test-device session", status, body, error)
            data = body.get("data") if isinstance(body, dict) else None
            access = data.get("access_token") if isinstance(data, dict) else None
            refresh = data.get("refresh_token") if isinstance(data, dict) else None
            if error:
                break
            if not envelope_ok(status, body) or not (isinstance(access, str) and isinstance(refresh, str)):
                add_case(results, "AUTH-LOGIN-SHAPE-" + alias, "POST", "/auth/login", "access_token and refresh_token", status, body, force="BLOCKED")
                continue
            role = data.get("role") if isinstance(data, dict) else None
            user_id = data.get("user_id") if isinstance(data, dict) else None
            sessions.append({"alias": alias, "device_id": device_id, "access": access, "refresh": refresh,
                             "role": role, "user_id": user_id})
            status, body, error = request(base, "GET", "/users/me", access)
            add_case(results, "IDENTITY-" + alias, "GET", "/users/me", "2xx authenticated account identity", status, body, error)
            profile = body.get("data") if isinstance(body, dict) else None
            same_identity = isinstance(profile, dict) and user_id is not None and profile.get("user_id") == user_id
            is_student = role == "STUDENT" and isinstance(profile, dict) and profile.get("role") == "STUDENT"
            results[-1]["identity_matches_login"] = same_identity
            results[-1]["student_role_confirmed"] = is_student
            if role in ("STUDENT", "LECTURER", "ADMIN"):
                results[-1]["identity_role"] = role
            if not same_identity or not is_student:
                results[-1]["status"] = "FAIL"

            # unauthenticated identity must be rejected; record contract status as non-2xx.
            status, body, error = request(base, "GET", "/users/me")
            add_case(results, "AUTH-ANON-ME-" + alias, "GET", "/users/me", "OpenAPI declares 401/403", status, body, error,
                     force=denial_result(status))

            surface_owner = is_student and same_identity and not broad_done
            if surface_owner:
                broad_done = True
                status, body, error = request(base, "GET", "/lecturer/course-classes/my-classes", access)
                add_case(results, "ROLE-LECTURER-" + alias, "GET", "/lecturer/course-classes/my-classes", "student access denied (401/403)", status, body, error,
                         force=denial_result(status))
                for path, operation in contract_gets(spec):
                    variants = [(None, None)]
                    if path == "/search":
                        variants = [(kind, kind) for kind in ("USER", "QUESTION", "SESSION")]
                    for _, kind in variants:
                        full_path = path + query_for(operation, kind)
                        case_suffix = ("-" + kind) if kind else ""
                        status, body, error = request(base, "GET", full_path, access)
                        add_case(results, "STUDENT-GET-" + path.strip("/").upper().replace("/", "-") + case_suffix + "-" + alias,
                                 "GET", full_path, "OpenAPI documented 2xx read with success envelope", status, body, error)
                status, body, error = request(base, "GET", "/sessions/my-enrolled-subjects", access)
                add_case(results, "CONTRACT-ENROLLED-LEGACY-" + alias, "GET", "/sessions/my-enrolled-subjects",
                         "legacy OpenAPI route; current app uses another route", status, body, error, force="WAITING")

            # Refresh current tokens, then verify rotated refresh token works after logout revocation.
            status, body, error = request(base, "POST", "/auth/refresh", payload={"refresh_token": refresh})
            add_case(results, "AUTH-REFRESH-" + alias, "POST", "/auth/refresh", "OpenAPI 2xx token refresh", status, body, error)
            refreshed = body.get("data") if isinstance(body, dict) else None
            if isinstance(refreshed, dict) and isinstance(refreshed.get("access_token"), str):
                session = sessions[-1]
                session["access"] = refreshed["access_token"]
                session["refresh"] = refreshed.get("refresh_token", refresh)
                status, body, error = request(base, "GET", "/users/me", session["access"])
                add_case(results, "IDENTITY-AFTER-REFRESH-" + alias, "GET", "/users/me", "2xx identity with refreshed access token", status, body, error)
                refreshed_profile = body.get("data") if isinstance(body, dict) else None
                same_refreshed_identity = isinstance(refreshed_profile, dict) and refreshed_profile.get("user_id") == session["user_id"] and refreshed_profile.get("role") == "STUDENT"
                results[-1]["identity_matches_login"] = same_refreshed_identity
                if not same_refreshed_identity:
                    results[-1]["status"] = "FAIL"

            if surface_owner:
                status, body, error = request(base, "GET", "/sessions/my-enrolled-course-classes?limit=10", sessions[-1]["access"])
                add_case(results, "CONTRACT-ENROLLED-CLIENT-" + alias, "GET", "/sessions/my-enrolled-course-classes?limit=10",
                         "current client route; expect 2xx success envelope", status, body, error)

    finally:
        for session in sessions:
            alias = session["alias"]
            status, body, error = request(base, "POST", "/auth/logout", session["access"])
            add_case(results, "AUTH-LOGOUT-" + alias, "POST", "/auth/logout", "2xx logout of generated test-device session", status, body, error)
            status, body, error = request(base, "POST", "/auth/refresh", payload={"refresh_token": session["refresh"]})
            add_case(results, "AUTH-REVOKED-" + alias, "POST", "/auth/refresh", "old refresh token rejected after logout", status, body, error,
                     force="BLOCKED" if status is None else "PASS" if status in (400, 401, 403) else "FAIL")

    report = {"phase": "baseline", "classification": "real API smoke; not whole acceptance", "timestamp_utc": now(),
              "tested_sha": __import__("subprocess").check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
              "api_host": urllib.parse.urlparse(base).hostname, "accounts": [str(a["alias"]) for a in accounts], "cases": results}
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"cases": len(results), "output": args.output, "counts": {s: sum(c["status"] == s for c in results) for s in ("PASS", "FAIL", "BLOCKED", "WAITING")}}))
    auth_blocked = any(c["case_id"].startswith("AUTH-LOGIN-") and c["http_status"] in (401, 403) for c in results)
    return 2 if not sessions or auth_blocked or any(c["status"] == "BLOCKED" for c in results) else 0


if __name__ == "__main__":
    sys.exit(main())
