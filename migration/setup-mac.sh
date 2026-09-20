#!/bin/bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SNAP="$ROOT/migration/windows-environment"
LOG="$ROOT/migration/mac-migration.log"
STATE="$ROOT/migration/mac-migration-state"

mkdir -p "$ROOT/migration"
exec > >(tee -a "$LOG") 2>&1

echo "============================================================"
echo " PUBGET — AUTOMATIC MAC ENVIRONMENT MIGRATOR"
echo "============================================================"
echo "Started: $(date)"
echo "Project: $ROOT"
echo

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

fail() {
  echo
  echo "ERROR: $1"
  echo "Log: $LOG"
  exit 1
}

ok() {
  echo "OK: $1"
}

warn() {
  echo "WARNING: $1"
}

run() {
  echo
  echo "+ $*"
  "$@"
}

version_ge() {
  # version_ge A B => true when A >= B
  [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

# ------------------------------------------------------------
# Basic validation
# ------------------------------------------------------------

[ -d "$SNAP" ] || fail "Windows environment snapshot not found."

[ -f "$ROOT/pubspec.yaml" ] || fail "pubspec.yaml not found."

OS_VERSION="$(sw_vers -productVersion)"
ARCH="$(uname -m)"

echo "macOS: $OS_VERSION"
echo "Architecture: $ARCH"

if [ "$ARCH" != "x86_64" ]; then
  warn "This machine is not Intel x86_64. Continuing with detected architecture."
fi

# Monterey safety boundary
if ! version_ge "$OS_VERSION" "12.0.0"; then
  fail "macOS 12 or newer is required by this migration plan."
fi

# ------------------------------------------------------------
# Read project requirements
# ------------------------------------------------------------

DART_MIN="$(sed -nE "s/.*sdk:[[:space:]]*['\"]?>=([0-9]+\.[0-9]+\.[0-9]+).*/\1/p" "$ROOT/pubspec.yaml" | head -1)"

[ -n "$DART_MIN" ] || DART_MIN="3.8.0"

echo
echo "Pubget minimum Dart: $DART_MIN"

# ------------------------------------------------------------
# Homebrew
# ------------------------------------------------------------

if command -v brew >/dev/null 2>&1; then
  ok "Homebrew already installed."
else
  warn "Homebrew not installed."
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || \
    fail "Homebrew installation failed."
fi

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# ------------------------------------------------------------
# Git
# ------------------------------------------------------------

if command -v git >/dev/null 2>&1; then
  ok "Git: $(git --version)"
else
  brew install git || fail "Git installation failed."
fi

# ------------------------------------------------------------
# Node / npm
# ------------------------------------------------------------

if command -v node >/dev/null 2>&1; then
  ok "Node: $(node --version)"
else
  brew install node@20 || brew install node || fail "Node installation failed."
fi

if command -v npm >/dev/null 2>&1; then
  ok "npm: $(npm --version)"
fi

# ------------------------------------------------------------
# Firebase CLI
# ------------------------------------------------------------

if command -v firebase >/dev/null 2>&1; then
  ok "Firebase CLI: $(firebase --version 2>/dev/null)"
else
  echo "Installing Firebase CLI..."
  npm install -g firebase-tools || fail "Firebase CLI installation failed."
fi

# ------------------------------------------------------------
# FlutterFire CLI
# ------------------------------------------------------------

if command -v flutterfire >/dev/null 2>&1; then
  ok "FlutterFire CLI already installed."
else
  if command -v dart >/dev/null 2>&1; then
    dart pub global activate flutterfire_cli || warn "FlutterFire CLI could not be installed yet."
  fi
fi

# ------------------------------------------------------------
# Python
# ------------------------------------------------------------

if command -v python3 >/dev/null 2>&1; then
  ok "Python: $(python3 --version)"
else
  brew install python || fail "Python installation failed."
fi

# ------------------------------------------------------------
# Flutter
# ------------------------------------------------------------

echo
echo "============================================================"
echo " FLUTTER RECONSTRUCTION"
echo "============================================================"

FLUTTER_ROOT="$HOME/develop/flutter"
FLUTTER_REPO="https://github.com/flutter/flutter.git"

CURRENT_FLUTTER="$(command -v flutter || true)"

# If current Flutter is not a real git checkout, preserve it and
# create a clean official checkout beside it.
if [ -n "$CURRENT_FLUTTER" ]; then
  CURRENT_ROOT="$(cd "$(dirname "$CURRENT_FLUTTER")/.." 2>/dev/null && pwd || true)"

  if [ -d "$CURRENT_ROOT/.git" ]; then
    REMOTE="$(git -C "$CURRENT_ROOT" remote get-url origin 2>/dev/null || true)"

    if [[ "$REMOTE" == *"github.com/flutter/flutter"* ]]; then
      FLUTTER_ROOT="$CURRENT_ROOT"
      ok "Official Flutter checkout detected: $FLUTTER_ROOT"
    else
      warn "Existing Flutter has a non-standard remote."
    fi
  else
    warn "Existing Flutter is not a standard Git checkout."
  fi
fi

# If existing Flutter is unsuitable, use an official checkout.
NEED_FLUTTER=1

if [ -x "$FLUTTER_ROOT/bin/flutter" ]; then
  EXISTING_DART="$("$FLUTTER_ROOT/bin/flutter" --version 2>/dev/null | sed -nE 's/.*Dart ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -1 || true)"

  if [ -n "$EXISTING_DART" ] && version_ge "$EXISTING_DART" "$DART_MIN"; then
    NEED_FLUTTER=0
    ok "Existing Flutter provides Dart $EXISTING_DART, satisfying Pubget."
  fi
fi

if [ "$NEED_FLUTTER" -eq 1 ]; then
  echo
  echo "Selecting official Flutter automatically..."

  TEMP_FLUTTER="$HOME/develop/flutter-official"

  if [ -d "$TEMP_FLUTTER/.git" ]; then
    git -C "$TEMP_FLUTTER" fetch --tags --quiet || true
  else
    mkdir -p "$HOME/develop"
    git clone "$FLUTTER_REPO" "$TEMP_FLUTTER" || fail "Could not clone official Flutter."
  fi

  # Find the newest stable tag whose Dart SDK satisfies Pubget.
  # Flutter tags are tested by actually checking their bundled Dart SDK.
  BEST_TAG=""

  git -C "$TEMP_FLUTTER" fetch --tags --quiet || true

  while IFS= read -r TAG; do
    [ -n "$TAG" ] || continue

    git -C "$TEMP_FLUTTER" checkout -q "$TAG" 2>/dev/null || continue

    DART_VERSION="$("$TEMP_FLUTTER/bin/dart" --version 2>&1 | sed -nE 's/.*Dart SDK version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -1 || true)"

    if [ -n "$DART_VERSION" ] && version_ge "$DART_VERSION" "$DART_MIN"; then
      BEST_TAG="$TAG"
      break
    fi
  done < <(git -C "$TEMP_FLUTTER" tag -l '3.*' --sort=-version:refname)

  [ -n "$BEST_TAG" ] || fail "Could not find a Flutter release compatible with Pubget's Dart requirement."

  echo "Selected official Flutter: $BEST_TAG"

  git -C "$TEMP_FLUTTER" checkout -q "$BEST_TAG"

  if [ "$FLUTTER_ROOT" != "$TEMP_FLUTTER" ]; then
    if [ -d "$HOME/develop/flutter-migrated" ]; then
      rm -rf "$HOME/develop/flutter-migrated"
    fi

    mv "$TEMP_FLUTTER" "$HOME/develop/flutter-migrated"
    FLUTTER_ROOT="$HOME/develop/flutter-migrated"
  fi

  export PATH="$FLUTTER_ROOT/bin:$HOME/.pub-cache/bin:$PATH"

  ok "Flutter selected: $("$FLUTTER_ROOT/bin/flutter" --version | head -1)"
fi

export PATH="$FLUTTER_ROOT/bin:$HOME/.pub-cache/bin:$PATH"

# ------------------------------------------------------------
# Android SDK
# ------------------------------------------------------------

echo
echo "============================================================"
echo " ANDROID ENVIRONMENT"
echo "============================================================"

ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_HOME
export ANDROID_SDK_ROOT="$ANDROID_HOME"

mkdir -p "$ANDROID_HOME"

if command -v sdkmanager >/dev/null 2>&1; then
  ok "Android SDK command-line tools detected."
else
  warn "sdkmanager not currently available."
fi

# Use Flutter to validate Android setup.
"$FLUTTER_ROOT/bin/flutter" config --android-sdk "$ANDROID_HOME" >/dev/null 2>&1 || true

# ------------------------------------------------------------
# PATH persistence
# ------------------------------------------------------------

SHELL_RC="$HOME/.zshrc"

touch "$SHELL_RC"

add_path() {
  local LINE="$1"
  grep -Fqx "$LINE" "$SHELL_RC" 2>/dev/null || echo "$LINE" >> "$SHELL_RC"
}

add_path 'export PATH="$HOME/develop/flutter-migrated/bin:$HOME/develop/flutter/bin:$HOME/.pub-cache/bin:$PATH"'
add_path 'export ANDROID_HOME="$HOME/Library/Android/sdk"'
add_path 'export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"'

# ------------------------------------------------------------
# VS Code extensions
# ------------------------------------------------------------

echo
echo "============================================================"
echo " VS CODE EXTENSIONS"
echo "============================================================"

if command -v code >/dev/null 2>&1 && [ -f "$SNAP/06-vscode-extensions.txt" ]; then
  grep -oE '[A-Za-z0-9_.-]+\.[A-Za-z0-9_.-]+' "$SNAP/06-vscode-extensions.txt" |
    sort -u |
    while IFS= read -r EXT; do
      [ -n "$EXT" ] || continue
      code --install-extension "$EXT" --force >/dev/null 2>&1 || \
        warn "Could not install VS Code extension: $EXT"
    done
else
  warn "VS Code CLI unavailable; extensions were not automatically installed."
fi

# ------------------------------------------------------------
# Python packages from snapshot
# ------------------------------------------------------------

echo
echo "============================================================"
echo " PYTHON ENVIRONMENT"
echo "============================================================"

PY_REQ="$SNAP/08-python-packages.txt"

if command -v python3 >/dev/null 2>&1 && [ -f "$PY_REQ" ]; then
  python3 -m pip install --user -r "$PY_REQ" 2>/dev/null || \
    warn "Some Windows Python packages are not compatible with macOS/Python 3."
fi

# ------------------------------------------------------------
# Dart global packages
# ------------------------------------------------------------

if [ -f "$SNAP/09-dart-global.txt" ]; then
  export PATH="$HOME/.pub-cache/bin:$PATH"

  if grep -qi "flutterfire_cli" "$SNAP/09-dart-global.txt"; then
    "$FLUTTER_ROOT/bin/dart" pub global activate flutterfire_cli || \
      warn "FlutterFire CLI activation failed."
  fi
fi

# ------------------------------------------------------------
# Flutter packages and project dependencies
# ------------------------------------------------------------

echo
echo "============================================================"
echo " PUBGET DEPENDENCIES"
echo "============================================================"

cd "$ROOT"

"$FLUTTER_ROOT/bin/flutter" pub get || \
  fail "Flutter pub get failed."

# ------------------------------------------------------------
# Firebase / FlutterFire verification
# ------------------------------------------------------------

echo
echo "============================================================"
echo " FIREBASE"
echo "============================================================"

command -v firebase >/dev/null 2>&1 && firebase --version || warn "Firebase CLI unavailable."

export PATH="$HOME/.pub-cache/bin:$PATH"

command -v flutterfire >/dev/null 2>&1 && flutterfire --version || \
  warn "FlutterFire CLI unavailable."

# ------------------------------------------------------------
# Flutter doctor
# ------------------------------------------------------------

echo
echo "============================================================"
echo " FINAL FLUTTER DOCTOR"
echo "============================================================"

"$FLUTTER_ROOT/bin/flutter" doctor -v || true

# ------------------------------------------------------------
# Project verification
# ------------------------------------------------------------

echo
echo "============================================================"
echo " PROJECT VERIFICATION"
echo "============================================================"

"$FLUTTER_ROOT/bin/flutter" analyze || warn "Flutter analyze reported issues."

"$FLUTTER_ROOT/bin/flutter" test || warn "Flutter tests reported failures or no tests."

# ------------------------------------------------------------
# Save state
# ------------------------------------------------------------

cat > "$STATE" <<EOF
PUBGET_MIGRATION_COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
MACOS=$OS_VERSION
ARCH=$ARCH
FLUTTER_ROOT=$FLUTTER_ROOT
FLUTTER_VERSION=$("$FLUTTER_ROOT/bin/flutter" --version 2>/dev/null | head -1)
DART_VERSION=$("$FLUTTER_ROOT/bin/dart" --version 2>&1 | head -1)
NODE_VERSION=$(node --version 2>/dev/null || echo unavailable)
NPM_VERSION=$(npm --version 2>/dev/null || echo unavailable)
PYTHON_VERSION=$(python3 --version 2>&1 || echo unavailable)
FIREBASE_VERSION=$(firebase --version 2>/dev/null || echo unavailable)
EOF

echo
echo "============================================================"
echo " MIGRATION FINISHED"
echo "============================================================"
echo "State: $STATE"
echo "Log:   $LOG"
echo
echo "The migrator completed the automatic reconstruction."
echo "Review the FINAL FLUTTER DOCTOR and PROJECT VERIFICATION sections above."
