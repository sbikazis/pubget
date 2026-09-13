#!/usr/bin/env python3
"""Fetch and validate Pubget's public Firebase Hosting Web configuration."""

from __future__ import annotations

import json
import re
import sys
import urllib.request
from pathlib import Path


PROJECT_ID = "pubget-aaf27"
PROJECT_NUMBER = "452313838148"
CONFIG_URL = f"https://{PROJECT_ID}.web.app/__/firebase/init.js"


def fail(message: str) -> None:
    print(f"Firebase Web configuration error: {message}", file=sys.stderr)
    raise SystemExit(2)


def main() -> None:
    if len(sys.argv) != 2:
        fail("expected one temporary output path")

    try:
        with urllib.request.urlopen(CONFIG_URL, timeout=20) as response:
            source = response.read().decode("utf-8")
    except Exception as error:
        fail(f"could not fetch the public Hosting configuration ({error})")

    match = re.search(r"firebase\.initializeApp\((\{.*?\})\);", source, re.DOTALL)
    if match is None:
        fail("Firebase Hosting returned an unsupported response")

    try:
        config = json.loads(match.group(1))
    except json.JSONDecodeError as error:
        fail(f"Firebase Hosting returned invalid JSON ({error})")

    if config.get("projectId") != PROJECT_ID:
        fail("project ID does not match Pubget")
    if str(config.get("messagingSenderId", "")) != PROJECT_NUMBER:
        fail("messaging sender ID does not match Pubget")

    app_id = str(config.get("appId", ""))
    if not app_id.startswith(f"1:{PROJECT_NUMBER}:web:"):
        fail("Web app ID does not belong to Pubget")

    required = {
        "FIREBASE_WEB_API_KEY": config.get("apiKey"),
        "FIREBASE_WEB_APP_ID": app_id,
        "FIREBASE_WEB_MESSAGING_SENDER_ID": config.get("messagingSenderId"),
        "FIREBASE_WEB_PROJECT_ID": config.get("projectId"),
        "FIREBASE_WEB_AUTH_DOMAIN": config.get("authDomain"),
    }
    missing = [key for key, value in required.items() if not value]
    if missing:
        fail(f"public Hosting configuration is missing {', '.join(missing)}")

    defines = {
        **required,
        "FIREBASE_WEB_STORAGE_BUCKET": config.get("storageBucket", ""),
        "FIREBASE_WEB_MEASUREMENT_ID": config.get("measurementId", ""),
    }
    Path(sys.argv[1]).write_text(json.dumps(defines), encoding="utf-8")


if __name__ == "__main__":
    main()