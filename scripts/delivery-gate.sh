#!/usr/bin/env sh
set -eu

REPOSITORY_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

cd "$REPOSITORY_ROOT/frontend"
flutter pub get
dart run build_runner build --delete-conflicting-outputs

cd "$REPOSITORY_ROOT/frontend"
dart format --set-exit-if-changed .
flutter analyze
flutter test

cd "$REPOSITORY_ROOT/backend"
npm ci
npm run validate:delivery

echo "HOSSPI delivery gate passed."
