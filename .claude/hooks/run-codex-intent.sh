#!/bin/bash

set -euo pipefail

INTENT="${1:-}"
GOAL="${2:-autopilot-goal}"
MODEL="${3:-unset}"
PROMPT="[intent=${INTENT}] goal=${GOAL}"

if [ -z "$INTENT" ]; then
  echo "usage: $0 <intent> [goal] [model]" >&2
  exit 2
fi

if [ "${DEV_HARNESS_TEST_MODE:-false}" = "true" ]; then
  echo "test-mode codex intent=${INTENT} model=${MODEL}"
  echo "goal=${GOAL}"
  exit 0
fi

if [ "$MODEL" != "unset" ]; then
  codex exec --model "$MODEL" "$PROMPT"
  exit 0
fi

codex exec "$PROMPT"
