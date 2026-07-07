#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
DEVICE="${PATROL_DEVICE:-chrome}"
FULL_SUITE="${PATROL_FULL_SUITE:-false}"
HEADLESS="${PATROL_HEADLESS:-true}"

FRONTEND_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$FRONTEND_ROOT"

export PATH="$PATH:$HOME/.pub-cache/bin"
export PATROL_GIT_SHA="$(git -C "$FRONTEND_ROOT" rev-parse HEAD 2>/dev/null || true)"

flutter pub get

ARGS=(test -d "$DEVICE" --web-reporter '["json","html","list"]' --web-results-dir build/patrol_web_results --web-report-dir build/patrol_web_report --web-video=retain-on-failure)

if [[ "$HEADLESS" == "true" ]]; then
  ARGS+=(--web-headless=true)
fi

if [[ -n "$TARGET" ]]; then
  ARGS+=(-t "$TARGET")
elif [[ "$FULL_SUITE" != "true" ]]; then
  ARGS+=(-t patrol_test/smoke_test.dart)
fi

patrol "${ARGS[@]}"
