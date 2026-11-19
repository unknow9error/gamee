#!/usr/bin/env sh
set -eu
# Local assertions only: no provider credentials or generation requests.
flutter analyze
flutter test --concurrency=1
node --test test/narration_generator_test.mjs
