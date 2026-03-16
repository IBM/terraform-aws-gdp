#!/usr/bin/env bash
# Build vpc-cleanup binaries for all supported platforms.
# Run this once after cloning, or when Go source changes.
#
# Usage:  bash scripts/build.sh
#         PLATFORMS="linux/amd64 darwin/arm64" bash scripts/build.sh
#
# Outputs pre-built binaries to scripts/bin/ so that terraform destroy
# can run the cleanup tool without needing Go installed on the target machine.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/vpc-cleanup"
BIN_DIR="$SCRIPT_DIR/bin"

PLATFORMS="${PLATFORMS:-linux/amd64 darwin/arm64 windows/amd64}"

mkdir -p "$BIN_DIR"

echo "Downloading Go module dependencies..."
(cd "$SRC_DIR" && go mod download)

echo "Building vpc-cleanup for platforms: $PLATFORMS"
for platform in $PLATFORMS; do
  OS="${platform%/*}"
  ARCH="${platform#*/}"
  EXT=""
  [[ "$OS" == "windows" ]] && EXT=".exe"
  OUTPUT="$BIN_DIR/vpc-cleanup-${OS}-${ARCH}${EXT}"
  echo "  -> $OUTPUT"
  (cd "$SRC_DIR" && \
    GOOS="$OS" GOARCH="$ARCH" CGO_ENABLED=0 \
    go build -ldflags="-s -w" -trimpath -o "$OUTPUT" .)
  chmod +x "$OUTPUT"
done

echo ""
echo "Done. Binaries:"
ls -lh "$BIN_DIR"/vpc-cleanup-* 2>/dev/null || echo "  (none)"
