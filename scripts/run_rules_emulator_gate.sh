#!/usr/bin/env bash
# Deterministic Phase-01 rules gate.
# Runs Firestore + Storage rules suites against the local emulators under the
# project ID the rules tests actually use (demo-pubget-security).
#
# Requirements:
#   - JDK 21+ on PATH (Firestore emulator)
#   - firebase CLI on PATH
# Usage: ./scripts/run_rules_emulator_gate.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ID="demo-pubget-security"

command -v java >/dev/null 2>&1 || { echo "ERR: java (JDK 21) not on PATH"; exit 1; }
JAVA_MAJOR="$(java -version 2>&1 | head -1 | sed -E 's/.*version "([0-9]+).*/\1/')"
if [ "$JAVA_MAJOR" -lt 21 ]; then
  echo "ERR: Firestore emulator requires JDK 21; found $(java -version 2>&1 | head -1)"
  echo "     Set JAVA_HOME to a JDK 21 install, e.g."
  echo "     /Users/sbikazis/develop/jdk-21.0.12.1+1/Contents/Home"
  exit 1
fi
echo "Using $(java -version 2>&1 | head -1)"

cd "$ROOT" || exit 1
firebase emulators:exec --project "$PROJECT_ID" --only firestore,storage \
  'cd functions; FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node --test test/firestore.rules.test.js; FS_RC=$?; FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node --test test/storage.rules.test.js; ST_RC=$?; echo "FS_RC=$FS_RC"; echo "ST_RC=$ST_RC"; exit $((FS_RC || ST_RC))'