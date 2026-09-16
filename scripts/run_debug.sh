#!/usr/bin/env bash
set -euo pipefail
if [[ ! -f .env ]]; then
  echo 'Missing .env. Copy .env.example to .env and fill ARKAD_DEV_OPENROUTER_KEY.' >&2
  exit 1
fi
exec flutter run --dart-define-from-file=.env "$@"
