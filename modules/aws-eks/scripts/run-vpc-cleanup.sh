#!/usr/bin/env bash
# Detects the current OS/architecture and runs the matching vpc-cleanup binary.
# Falls back to building from source if the binary is missing and Go is available.
#
# All arguments are forwarded to the binary unchanged.
# AWS credentials can be passed as flags (matching terraform.tfvars fields):
#   --access-key-id / --secret-access-key  — static credentials
#   --profile                              — named profile
# Or via environment variables as a fallback:
#   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
#   AWS_PROFILE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
SRC_DIR="$SCRIPT_DIR/vpc-cleanup"

# Detect OS and CPU architecture
_RAW_OS="$(uname -s)"
ARCH="$(uname -m)"

case "$_RAW_OS" in
  Linux*)                     OS="linux"  ;;
  Darwin*)                    OS="darwin" ;;
  MINGW* | MSYS* | CYGWIN*)  OS="windows" ;;
  *)
    echo "ERROR: Unsupported OS: $_RAW_OS" >&2
    exit 1
    ;;
esac

case "$ARCH" in
  x86_64)          ARCH="amd64" ;;
  aarch64 | arm64) ARCH="arm64" ;;
  *)
    echo "ERROR: Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

EXT=""
[ "$OS" = "windows" ] && EXT=".exe"

BINARY="$BIN_DIR/vpc-cleanup-${OS}-${ARCH}${EXT}"

if [ ! -f "$BINARY" ]; then
  if command -v go >/dev/null 2>&1; then
    echo "vpc-cleanup binary not found for ${OS}/${ARCH} — building from source..."
    mkdir -p "$BIN_DIR"
    (cd "$SRC_DIR" && go mod download && go build -o "$BINARY" .)
    chmod +x "$BINARY"
    echo "Build complete: $BINARY"
  else
    echo "ERROR: Pre-built binary not found: $BINARY" >&2
    echo "       Install Go and run:  bash $SCRIPT_DIR/build.sh" >&2
    exit 1
  fi
fi

exec "$BINARY" "$@"
