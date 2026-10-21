"""Offline structural checks for the hand-maintained Postman collection."""

import json
import re
import unittest
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
COLLECTION = ROOT / "qa/api/quizhub-qa.postman_collection.json"
ENVIRONMENT = ROOT / "qa/api/quizhub-qa.environment.template.json"
VARIABLE = re.compile(r"\{\{([^}]+)\}\}")


def load_inputs():
    collection = json.loads(COLLECTION.read_text(encoding="utf-8"))
    environment = json.loads(ENVIRONMENT.read_text(encoding="utf-8"))
    values = {entry["key"]: entry["value"] for entry in environment["values"]}
    requests = [item for folder in collection["item"] for item in folder["item"]]
    return collection, environment, values, requests


def rendered_body(raw):
    content = 'Tiếng Việt: "trích dẫn"\ndòng hai; dấu gạch chéo \\ cuối'
    fragments = {
        "post_content_json": json.dumps(content, ensure_ascii=False),
        "comment_content_json": json.dumps(content, ensure_ascii=False),
        "profile_update_body": json.dumps({"full_name": content}, ensure_ascii=False),
        "post_update_body": json.dumps({"content": content}, ensure_ascii=False),
    }

    def replace(match):
        key = match.group(1)
        if key in fragments:
            return fragments[key]
        if key in {"post_id", "user_b_id", "requester_id"}:
            return "42"
        return "test-value"

    return VARIABLE.sub(replace, raw), content


class CollectionChecks(unittest.TestCase):
    def test_environment_is_empty_and_points_to_invalid_host(self):
        _, environment, values, _ = load_inputs()
        self.assertEqual(urlparse(values["base_url"]).hostname, "example.invalid")
        self.assertNotIn("_postman_exported_at", environment)
        self.assertNotIn("_postman_exported_using", environment)
        for key, value in values.items():
            if key != "base_url":
                self.assertEqual(value, "", f"template value must remain blank: {key}")

    def test_variables_auth_urls_and_scripts_are_safe(self):
        collection, _, values, requests = load_inputs()
        serialized = json.dumps(collection, ensure_ascii=False)
        refs = set(VARIABLE.findall(serialized))
        self.assertEqual(refs, set(values))
        self.assertFalse(collection.get("event"), "collection scripts are not expected")
        for folder in collection["item"]:
            self.assertFalse(folder.get("event"), folder["name"])
        for request in requests:
            self.assertFalse(request.get("event"), request["name"])
            self.assertFalse(request.get("script"), request["name"])
            url = request["request"]["url"]
            self.assertTrue(url.startswith("{{base_url}}/"), request["name"])
            auth = request["request"].get("auth", {})
            if auth.get("type") == "bearer":
                for field in auth["bearer"]:
                    self.assertTrue(set(VARIABLE.findall(field["value"])) <= set(values))

    def test_rendered_raw_bodies_are_json_and_text_round_trips(self):
        _, _, _, requests = load_inputs()
        content = 'Tiếng Việt: "trích dẫn"\ndòng hai; dấu gạch chéo \\ cuối'
        saw_post = saw_comment = saw_numeric_id = False
        for item in requests:
            raw = item["request"].get("body", {}).get("raw")
            if raw is None:
                continue
            rendered, _ = rendered_body(raw)
            body = json.loads(rendered)
            if "post_content_json" in raw:
                self.assertEqual(body["content"], content)
                saw_post = True
            if "comment_content_json" in raw:
                self.assertEqual(body["content"], content)
                saw_comment = True
            if '"target_id": {{post_id}}' in raw:
                self.assertIsInstance(body["target_id"], int)
                saw_numeric_id = True
            if '"requester_id": {{requester_id}}' in raw:
                self.assertIsInstance(body["requester_id"], int)
                saw_numeric_id = True
        self.assertTrue(saw_post)
        self.assertTrue(saw_comment)
        self.assertTrue(saw_numeric_id)


if __name__ == "__main__":
    unittest.main()
