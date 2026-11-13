"""Repository hygiene gate for the Pubget client and Cloud Functions.

This exists because a broken "merge: resolve conflicts and sync local changes"
commit once landed 23 files containing literal `<<<<<<<`/`>>>>>>>` markers on
main, which made the whole client uncompilable while CI still had no check that
could catch it. Run locally with `python3 .github/scripts/hygiene_check.py`.

Exit code 0 = clean, 1 = at least one blocking problem.
"""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

# These files must be strict JSON; a half-merged index file silently breaks
# every `firebase deploy --only firestore:indexes`.
JSON_TARGETS = (
    "firestore.indexes.json",
    "functions/package.json",
    "firebase.json",
    "package.json",
)

# The Cloudflare R2 migration was reverted. Nothing in the client may import
# the deleted storage package again without deliberately reviving it.
DEAD_IMPORT_FRAGMENTS = (
    "core/storage/r2_",
    "core/storage/media_upload_service.dart",
    "core/storage/r2_storage_service.dart",
)

# Built at runtime so this file does not contain the very literal it scans
# for — otherwise the gate flags its own source as a leaked private key.
# A service-account JSON holds the PEM inline in a quoted string, so a
# substring match (not line-start) is required to catch it.
_PEM_PREFIX = "-----BEGIN "
PRIVATE_KEY_MARKERS = tuple(
    _PEM_PREFIX + kind + "-----"
    for kind in ("PRIVATE KEY", "RSA PRIVATE KEY", "EC PRIVATE KEY")
)

SKIP_SUFFIXES = (
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".apk", ".aab",
    ".ttf", ".otf", ".mp4", ".mp3", ".wav", ".pdf", ".zip", ".jar",
)


def tracked_files() -> list[str]:
    output = subprocess.check_output(
        ["git", "-C", str(ROOT), "ls-files"], text=True
    )
    return [line.strip() for line in output.splitlines() if line.strip()]


def read(path: pathlib.Path) -> str | None:
    if path.suffix.lower() in SKIP_SUFFIXES:
        return None
    try:
        if path.stat().st_size > 2_000_000:
            return None
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None


def main() -> int:
    problems: list[str] = []
    files = tracked_files()
    scanned = 0

    for relative in files:
        path = ROOT / relative
        if not path.is_file():
            continue
        text = read(path)
        if text is None:
            continue
        scanned += 1

        for number, line in enumerate(text.splitlines(), start=1):
            # `=======` is a valid Markdown setext underline, so only the two
            # unambiguous marker forms are checked.
            if line.startswith("<<<<<<< ") or line.startswith(">>>>>>> "):
                problems.append(
                    f"{relative}:{number}: unresolved merge conflict marker"
                )
            for marker in PRIVATE_KEY_MARKERS:
                if marker in line:
                    problems.append(
                        f"{relative}:{number}: tracked private key material"
                    )

        if relative.endswith(".dart"):
            for fragment in DEAD_IMPORT_FRAGMENTS:
                if fragment in text:
                    problems.append(
                        f"{relative}: import of removed R2 storage path "
                        f"({fragment})"
                    )

    for relative in JSON_TARGETS:
        path = ROOT / relative
        if not path.is_file():
            continue
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except ValueError as error:
            problems.append(f"{relative}: invalid JSON ({error})")

    # A service-account key may sit on a developer machine, but it must stay
    # ignored AND must never be tracked. The PEM marker scan above catches the
    # content; this name check catches an empty/renamed/encrypted variant and
    # also rejects a key that was force-added despite .gitignore.
    ignored = subprocess.run(
        ["git", "-C", str(ROOT), "check-ignore", "-q",
         "functions/serviceAccount.json"],
        check=False,
    ).returncode == 0
    if not ignored:
        problems.append(
            "functions/serviceAccount.json is not git-ignored; add it to "
            "functions/.gitignore before committing"
        )
    for relative in files:
        if "serviceaccount" in relative.lower() and relative.lower().endswith(
            ".json"
        ):
            problems.append(
                f"{relative}: a service-account key is tracked in git; remove "
                f"it, rotate the key in the Firebase console, and use "
                f"Application Default Credentials instead"
            )

    if problems:
        print("Repository hygiene FAILED:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print(f"Repository hygiene OK: {scanned} of {len(files)} tracked files scanned")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
