#!/usr/bin/env bash
# Idempotent dev-environment bootstrap for the Pubget Flutter + Firebase project.
# Safe to run repeatedly: it only does work that is missing.
set -euo pipefail

FLUTTER_VERSION="3.47.2"
FLUTTER_HOME="${HOME}/flutter"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Pubget environment setup (repo: ${REPO_ROOT})"

# 1. Flutter SDK (stable). Installed once; reused on later runs.
if [ ! -x "${FLUTTER_HOME}/bin/flutter" ]; then
  echo "==> Installing Flutter ${FLUTTER_VERSION} to ${FLUTTER_HOME}"
  ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${ARCHIVE}"
  curl -fL -o "/tmp/${ARCHIVE}" "${URL}"
  tar -xf "/tmp/${ARCHIVE}" -C "${HOME}"
  rm -f "/tmp/${ARCHIVE}"
else
  echo "==> Flutter already present at ${FLUTTER_HOME}"
fi

export PATH="${FLUTTER_HOME}/bin:${PATH}"
git config --global --add safe.directory "${FLUTTER_HOME}" || true

# Persist Flutter on PATH for interactive/login shells and terminals.
if ! grep -q 'flutter/bin' "${HOME}/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/flutter/bin:$PATH"' >> "${HOME}/.bashrc"
fi

flutter --version

# 2. Node dependencies.
# The committed package-lock.json files pin tarball URLs to Replit's internal
# proxy (package-firewall.replit.local), which is unreachable outside Replit.
# Rewrite them in the checked-out tree (not committed) so npm can fetch from the
# public registry. This is idempotent.
echo "==> Normalizing npm lockfile registry URLs"
for lock in "${REPO_ROOT}/package-lock.json" "${REPO_ROOT}/functions/package-lock.json"; do
  if [ -f "${lock}" ]; then
    sed -i 's#http://package-firewall.replit.local/npm/#https://registry.npmjs.org/#g' "${lock}"
  fi
done

echo "==> Installing root npm dependencies"
(cd "${REPO_ROOT}" && npm ci)

echo "==> Installing Cloud Functions npm dependencies"
(cd "${REPO_ROOT}/functions" && npm ci)

# 3. Flutter package dependencies.
echo "==> Fetching Flutter packages"
(cd "${REPO_ROOT}" && flutter pub get)

echo "==> Setup complete"
