#!/bin/bash

set -euo pipefail

AUTOMATION_FILE=".claude/project-automation.md"

if [ ! -f "$AUTOMATION_FILE" ]; then
  echo "risk-policy 검증 실패: $AUTOMATION_FILE 파일이 없습니다." >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "risk-policy 검증 실패: jq가 필요합니다." >&2
  exit 2
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

if [ -z "$COMMAND" ]; then
  exit 0
fi

get_value() {
  local key="$1"
  grep -E "^- ${key}:" "$AUTOMATION_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//"
}

csv_contains() {
  local csv="$1"
  local needle="$2"
  echo "$csv" | tr ',' '\n' | tr -d ' ' | grep -Fxq "$needle"
}

risk_tier="low"

if [[ "$COMMAND" =~ git[[:space:]]+push.*(--force|-f)([[:space:]]|$) ]] || [[ "$COMMAND" =~ rm[[:space:]].*-rf[[:space:]]+/ ]]; then
  risk_tier="critical"
elif [[ "$COMMAND" =~ (^|[[:space:]])(npm|pnpm|yarn)[[:space:]]+(install|add|remove|uninstall|update)([[:space:]]|$) ]] \
  || [[ "$COMMAND" =~ (^|[[:space:]])pip([0-9.]*)[[:space:]]+(install|uninstall)([[:space:]]|$) ]] \
  || [[ "$COMMAND" =~ (^|[[:space:]])poetry[[:space:]]+(add|remove|update)([[:space:]]|$) ]] \
  || [[ "$COMMAND" =~ (^|[[:space:]])cargo[[:space:]]+(add|remove)([[:space:]]|$) ]] \
  || [[ "$COMMAND" =~ (^|[[:space:]])go[[:space:]]+get([[:space:]]|$) ]] \
  || [[ "$COMMAND" =~ git[[:space:]]+branch[[:space:]]+(-D|--delete)([[:space:]]|$) ]]; then
  risk_tier="high"
fi

auto_apply=$(get_value "auto_apply_risk_tier")
require_user=$(get_value "require_user_for_risk_tier")

if csv_contains "$require_user" "$risk_tier"; then
  echo "risk-policy 차단: ${risk_tier} 변경은 사용자 명시 승인이 필요합니다." >&2
  echo "command=$COMMAND" >&2
  exit 2
fi

if csv_contains "$auto_apply" "$risk_tier"; then
  exit 0
fi

if [ "$risk_tier" = "high" ] || [ "$risk_tier" = "critical" ]; then
  echo "risk-policy 차단: ${risk_tier} 티어가 자동 허용 목록에 없습니다." >&2
  echo "command=$COMMAND" >&2
  exit 2
fi

exit 0
