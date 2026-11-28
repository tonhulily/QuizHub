#!/usr/bin/env python3
"""Disposable two-account REST probe; credentials are read from stdin only."""

import argparse
import json
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

PREFIX = "QA 20261128"
TIMEOUT = 15
SAFE_KEYS = {"case", "status", "http", "code", "count", "sha", "cleanup_remaining", "cleanup_unconfirmed", "environment", "command"}
SUCCESS_CODES = {"0000", "1000"}


def safe(event):
    """Emit allowlisted metadata only; never include messages or payload values."""
    row = {k: v for k, v in event.items() if k in SAFE_KEYS}
    for k in ("status", "command", "environment"):
        if k in row:
            row[k] = str(row[k])[:40]
    if "code" in row and not re.fullmatch(r"\d{4}", str(row["code"])):
        row.pop("code")
    for k in ("http", "count", "cleanup_remaining", "cleanup_unconfirmed"):
        if k in row:
            row[k] = max(0, int(row[k]))
    if "sha" in row and not re.fullmatch(r"[0-9a-f]{40}|unknown", str(row["sha"])):
        row["sha"] = "unknown"
    if "environment" in row and row["environment"] not in {"qa", "staging", "dev", "unknown"}:
        row["environment"] = "unknown"
    if "command" in row:
        row["command"] = "python3 qa/api/real_social_probe.py"
    print(json.dumps(row, ensure_ascii=True), flush=True)


def envelope(body):
    if not isinstance(body, dict):
        raise ValueError("invalid envelope")
    return body.get("data", body), body.get("code", "")


class Probe:
    def __init__(self, base_url):
        parsed = urllib.parse.urlsplit(base_url)
        if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
            raise ValueError("base_url must be an https URL without userinfo")
        self.base = base_url.rstrip("/")
        self.ids = {"post": [], "comment": []}
        self.opener = urllib.request.build_opener(_NoRedirect())

    def request(self, account, method, path, body=None, case="request", allow=(200, 201)):
        data = None if body is None else json.dumps(body, ensure_ascii=False).encode()
        headers = {"Accept": "application/json"}
        if account and account.get("token"):
            headers["Authorization"] = "Bearer " + account["token"]
        if data is not None:
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(self.base + path, data=data, headers=headers, method=method)
        try:
            with self.opener.open(req, timeout=TIMEOUT) as response:
                raw, status = response.read(), response.status
        except urllib.error.HTTPError as exc:
            raw, status = exc.read(), exc.code
        except Exception:
            safe({"case": case, "status": "BLOCKED", "http": 0})
            raise
        try:
            parsed = json.loads(raw) if raw else {}
        except (ValueError, UnicodeDecodeError):
            parsed = {}
        code = parsed.get("code", "") if isinstance(parsed, dict) else ""
        valid_code = code in SUCCESS_CODES
        ok = status in allow and (not 200 <= status < 300 or valid_code)
        safe({"case": case, "status": "HTTP_PASS" if ok else "HTTP_FAIL", "http": status, "code": code if valid_code else ""})
        return status, parsed

    def login(self, account, device_id):
        status, body = self.request(None, "POST", "/auth/login", {
            "email": account["email"], "password": account["password"],
            "device_id": device_id, "platform": "ANDROID", "device_name": "QA probe",
            "os_version": "QA", "app_version": "QA",
        }, "AUTH", (200,))
        data, code = envelope(body)
        token = data.get("access_token") if isinstance(data, dict) else None
        if status != 200 or code not in SUCCESS_CODES or not token:
            raise RuntimeError("authentication blocked")
        account["token"] = token

    def create_post(self, account, visibility, marker, case):
        status, body = self.request(account, "POST", "/posts", {
            "content": marker, "media_urls": [], "visibility": visibility,
            "post_type": "SOCIAL_POST",
        }, case, (200, 201))
        data, code = envelope(body)
        post_id = data.get("post_id") if isinstance(data, dict) else None
        if isinstance(post_id, int):
            self.ids["post"].append((account, post_id))
        if not isinstance(post_id, int) or status not in (200, 201) or code not in SUCCESS_CODES:
            safe({"case": case, "status": "BLOCKED", "cleanup_unconfirmed": int(not isinstance(post_id, int))})
            raise RuntimeError("create returned no trackable id")
        return post_id

    def cleanup(self):
        remaining = 0
        for account, comment_id in reversed(self.ids["comment"]):
            try:
                status, body = self.request(account, "DELETE", f"/comments/{comment_id}", case="CLEAN_COMMENT", allow=(200, 404))
                _, code = envelope(body) if status == 200 else ({}, "")
                remaining += status not in (200, 404) or (status == 200 and code not in SUCCESS_CODES)
            except Exception:
                remaining += 1
        for account, post_id in reversed(self.ids["post"]):
            try:
                status, body = self.request(account, "DELETE", f"/posts/{post_id}", case="CLEAN_POST", allow=(200, 404))
                _, code = envelope(body) if status == 200 else ({}, "")
                remaining += status not in (200, 404) or (status == 200 and code not in SUCCESS_CODES)
            except Exception:
                remaining += 1
        safe({"case": "CLEANUP", "status": "PASS" if remaining == 0 else "BLOCKED", "cleanup_remaining": remaining})


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def self_check():
    sample = {"case": "SELF_CHECK", "status": "PASS", "http": 201, "code": "0000", "count": 2,
             "sha": "0123456789abcdef0123456789abcdef01234567", "email": "secret@example.test", "message": "private"}
    import contextlib
    from io import StringIO
    out = StringIO()
    with contextlib.redirect_stdout(out):
        safe(sample)
    got = json.loads(out.getvalue())
    assert set(got) == SAFE_KEYS.intersection(sample)
    assert "secret@example.test" not in out.getvalue() and "private" not in out.getvalue()
    assert got["code"] == "0000" and got["http"] == 201
    out = StringIO()
    with contextlib.redirect_stdout(out):
        safe({"case": "SELF_CHECK", "status": "FAIL", "code": "private server detail"})
    assert "code" not in json.loads(out.getvalue()) and "private server detail" not in out.getvalue()
    for code, expected in (("0000", True), ("1000", True), ("9999", False), ("private message", False)):
        assert (code in SUCCESS_CODES) is expected
        assert (code if code in SUCCESS_CODES else "") == (code if expected else "")
    safe({"case": "SELF_CHECK", "status": "PASS", "count": len(got)})


def run(inp, output):
    sys.stdout = output
    try:
        sha = subprocess.run(["git", "rev-parse", "HEAD"], check=True, capture_output=True, text=True, timeout=2).stdout.strip()
    except Exception:
        sha = "unknown"
    environment = str(inp.get("environment", "unknown")).lower()
    safe({"case": "RUN", "status": "STARTED", "sha": sha, "environment": environment, "command": "python3 qa/api/real_social_probe.py"})
    accounts = inp.get("accounts", [])
    if len(accounts) != 2 or [a.get("alias") for a in accounts] != ["son", "nam"]:
        raise ValueError("accounts must be ordered son, nam")
    for a in accounts:
        if not a.get("email") or not a.get("password"):
            raise ValueError("missing account input")
    probe = Probe(inp["base_url"])
    marker = f"{PREFIX} {int(time.time())}-{uuid.uuid4().hex[:8]}"
    try:
        probe.login(accounts[0], "qa-probe-son-" + uuid.uuid4().hex)
        probe.login(accounts[1], "qa-probe-nam-" + uuid.uuid4().hex)
        a, b = accounts
        public_id = probe.create_post(a, "PUBLIC", marker + " public", "POST_PUBLIC")
        for who, case in ((a, "POST_A_READ"), (b, "POST_B_READ")):
            status, body = probe.request(who, "GET", f"/posts/{public_id}", case=case, allow=(200,))
            data, code = envelope(body)
            passed = status == 200 and code in SUCCESS_CODES and isinstance(data, dict) and data.get("content") == marker + " public"
            safe({"case": case + "_CONTENT", "status": "PASS" if passed else "FAIL", "http": status})
            assert passed
        status, body = probe.request(a, "GET", "/posts/me?limit=50", case="POSTS_ME", allow=(200,))
        data, code = envelope(body)
        items = data.get("items", []) if isinstance(data, dict) else []
        passed = status == 200 and code in SUCCESS_CODES and any(x.get("post_id") == public_id for x in items)
        safe({"case": "POSTS_ME_ASSERT", "status": "PASS" if passed else "FAIL", "count": len(items)})
        assert passed

        private_id = probe.create_post(a, "ONLY_ME", marker + " private", "POST_PRIVATE")
        status, body = probe.request(b, "GET", f"/posts/{private_id}", case="PRIVATE_B_READ", allow=(200, 403, 404))
        data, code = envelope(body) if isinstance(body, dict) else ({}, "")
        visible = isinstance(data, dict) and data.get("content") == marker + " private"
        if visible:
            safe({"case": "PRIVATE_B_ASSERT", "status": "FAIL", "http": status})
            raise AssertionError("ONLY_ME post visible to B")
        if status in (403, 404):
            safe({"case": "PRIVATE_B_ASSERT", "status": "PASS", "http": status})
        elif status == 200:
            safe({"case": "PRIVATE_B_ASSERT", "status": "PASS" if code in SUCCESS_CODES else "WAITING", "http": status})
        else:
            safe({"case": "PRIVATE_B_ASSERT", "status": "WAITING", "http": status})

        status, body = probe.request(b, "POST", "/comments", {
            "target_type": "POST", "target_id": public_id, "content": marker + " comment",
        }, "COMMENT_CREATE", (200, 201))
        data, _ = envelope(body)
        comment_id = data.get("comment_id") if isinstance(data, dict) else None
        _, code = envelope(body)
        if isinstance(comment_id, int):
            probe.ids["comment"].append((b, comment_id))
        if status not in (200, 201) or code not in SUCCESS_CODES or not isinstance(comment_id, int):
            safe({"case": "COMMENT_CREATE", "status": "BLOCKED", "cleanup_unconfirmed": int(not isinstance(comment_id, int))})
            raise RuntimeError("comment returned no trackable id")
        status, body = probe.request(a, "POST", "/react", {
            "target_type": "POST", "target_id": public_id, "reaction_type": "LIKE",
        }, "LIKE_ON", (200, 201))
        data, code = envelope(body)
        passed = status in (200, 201) and code in SUCCESS_CODES and isinstance(data, dict) and data.get("my_reaction") == "LIKE"
        safe({"case": "LIKE_ON_ASSERT", "status": "PASS" if passed else "FAIL", "http": status})
        assert passed
        status, body = probe.request(a, "POST", "/react", {
            "target_type": "POST", "target_id": public_id, "reaction_type": "LIKE",
        }, "LIKE_TOGGLE_OFF", (200, 201))
        data, code = envelope(body)
        passed = status in (200, 201) and code in SUCCESS_CODES and isinstance(data, dict) and data.get("my_reaction") in (None, "", "NONE")
        safe({"case": "LIKE_OFF_ASSERT", "status": "PASS" if passed else "FAIL", "http": status})
        assert passed
        status, body = probe.request(a, "GET", f"/comments?target_type=POST&target_id={public_id}&sort=newest&limit=20", case="COMMENT_LIST", allow=(200,))
        data, code = envelope(body)
        rows = data.get("items", []) if isinstance(data, dict) else []
        passed = status == 200 and code in SUCCESS_CODES and any(x.get("comment_id") == comment_id for x in rows)
        safe({"case": "COMMENT_LIST_ASSERT", "status": "PASS" if passed else "FAIL", "count": len(rows)})
        assert passed
        delete_status, delete_body = probe.request(b, "DELETE", f"/comments/{comment_id}", case="COMMENT_DELETE", allow=(200,))
        _, delete_code = envelope(delete_body) if delete_status == 200 else ({}, "")
        if delete_status == 200 and delete_code in SUCCESS_CODES:
            probe.ids["comment"].clear()
        status, body = probe.request(a, "GET", f"/comments?target_type=POST&target_id={public_id}&sort=newest&limit=20", case="COMMENT_ABSENT", allow=(200,))
        data, code = envelope(body)
        rows = data.get("items", []) if isinstance(data, dict) else []
        passed = status == 200 and code in SUCCESS_CODES and not any(x.get("comment_id") == comment_id for x in rows)
        safe({"case": "COMMENT_ABSENT_ASSERT", "status": "PASS" if passed else "FAIL", "count": len(rows)})
        assert passed
        for post_id in (public_id, private_id):
            delete_status, delete_body = probe.request(a, "DELETE", f"/posts/{post_id}", case="POST_DELETE", allow=(200,))
            _, delete_code = envelope(delete_body) if delete_status == 200 else ({}, "")
            if delete_status == 200 and delete_code in SUCCESS_CODES:
                probe.ids["post"] = [(owner, pid) for owner, pid in probe.ids["post"] if pid != post_id]
            status, body = probe.request(a, "GET", f"/posts/{post_id}", case="POST_ABSENT", allow=(200, 403, 404))
            data, code = envelope(body) if isinstance(body, dict) else ({}, "")
            deleted = isinstance(data, dict) and (data.get("is_deleted") is True or data.get("deleted") is True)
            if status in (403, 404) or deleted:
                safe({"case": "POST_ABSENT_ASSERT", "status": "PASS", "http": status})
            elif status == 200:
                safe({"case": "POST_ABSENT_ASSERT", "status": "WAITING", "http": status})
            else:
                safe({"case": "POST_ABSENT_ASSERT", "status": "FAIL", "http": status})
                raise AssertionError("post remains accessible after delete")
    finally:
        try:
            probe.cleanup()
        finally:
            for account in accounts:
                if account.get("token"):
                    try:
                        probe.request(account, "POST", "/auth/logout", case="LOGOUT", allow=(200,))
                    except Exception:
                        pass
                account.pop("token", None)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", help="write sanitized JSONL metadata to this path")
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    if args.self_check:
        self_check()
        return 0
    inp = json.load(sys.stdin)
    original_stdout = sys.stdout
    if args.output:
        from pathlib import Path
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        output = open(args.output, "w", encoding="utf-8")
    else:
        output = original_stdout
    try:
        try:
            run(inp, output)
            return 0
        except AssertionError:
            safe({"case": "RUN", "status": "FAIL"})
            return 1
        except Exception:
            safe({"case": "RUN", "status": "BLOCKED"})
            return 2
    finally:
        sys.stdout = original_stdout
        if output is not original_stdout:
            output.close()


if __name__ == "__main__":
    raise SystemExit(main())
