#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
TARGET="$ROOT_DIR/backend/src/modules/clinical-term/data/uganda-diagnosis-terms.js"

if [ -f "$TARGET" ]; then
  rm "$TARGET"
  echo "Deleted $TARGET"
else
  echo "No deletion needed; $TARGET is already absent."
fi
