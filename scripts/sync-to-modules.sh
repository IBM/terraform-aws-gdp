#!/bin/sh
#
# Copyright (c) IBM Corp. 2026
# SPDX-License-Identifier: Apache-2.0
#
# sync-to-modules.sh
#
# Synchronizes wait_for_guardium_ready.sh from common/scripts to all module directories.
# This ensures all modules have identical copies of the script for self-contained usage.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_SCRIPT="$SCRIPT_DIR/wait_for_guardium_ready.sh"
MODULES_DIR="$(cd "$SCRIPT_DIR/../modules" && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Synchronizing wait_for_guardium_ready.sh"
echo "=========================================="
echo ""

# Check if source script exists
if [ ! -f "$SOURCE_SCRIPT" ]; then
    printf "${RED}✗ Error: Source script not found: $SOURCE_SCRIPT${NC}\n"
    exit 1
fi

# Get source checksum
SOURCE_MD5=$(md5sum "$SOURCE_SCRIPT" | awk '{print $1}')
echo "Source: $SOURCE_SCRIPT"
echo "MD5:    $SOURCE_MD5"
echo ""

# Target modules
MODULES="collector central-manager aggregator"
SYNCED=0
FAILED=0

for module in $MODULES; do
    TARGET_DIR="$MODULES_DIR/$module/scripts"
    TARGET_SCRIPT="$TARGET_DIR/wait_for_guardium_ready.sh"

    # Create directory if it doesn't exist
    if [ ! -d "$TARGET_DIR" ]; then
        mkdir -p "$TARGET_DIR"
        printf "${YELLOW}  Created directory: $TARGET_DIR${NC}\n"
    fi

    # Copy script
    if cp "$SOURCE_SCRIPT" "$TARGET_SCRIPT"; then
        chmod +x "$TARGET_SCRIPT"
        TARGET_MD5=$(md5sum "$TARGET_SCRIPT" | awk '{print $1}')

        if [ "$SOURCE_MD5" = "$TARGET_MD5" ]; then
            printf "${GREEN}✓ $module${NC} - Synced successfully\n"
            SYNCED=$((SYNCED + 1))
        else
            printf "${RED}✗ $module${NC} - Checksum mismatch!\n"
            FAILED=$((FAILED + 1))
        fi
    else
        printf "${RED}✗ $module${NC} - Copy failed\n"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "=========================================="
if [ $FAILED -eq 0 ]; then
    printf "${GREEN}✓ All modules synchronized successfully${NC}\n"
    echo "Synced: $SYNCED modules"
    echo "MD5:    $SOURCE_MD5"
else
    printf "${RED}✗ Synchronization completed with errors${NC}\n"
    echo "Synced: $SYNCED modules"
    echo "Failed: $FAILED modules"
    exit 1
fi
echo "=========================================="

# Made with Bob
