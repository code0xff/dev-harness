#!/bin/bash

set -euo pipefail

# Write/Edit/MultiEdit 도구가 정책 파일을 직접 수정할 때 경고하거나 차단한다.
# 정책 파일: project-profile.md, project-approvals.md, project-automation.md
# preapproval_enforcement=block 이면 차단, 그 외에는 경고 로그만 남긴다.

AUTOMATION_FILE=".claude/project-automation.md"
WARN_FILE=".claude/state/policy-warnings.log"

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

PROTECTED_POLICY_FILES=(
  ".claude/project-profile.md"
  ".claude/project-approvals.md"
  ".claude/project-automation.md"
)

is_protected_policy_file() {
  local path="$1"
  for pattern in "${PROTECTED_POLICY_FILES[@]}"; do
    if [[ "$path" == *"$pattern" ]]; then
      return 0
    fi
  done
  return 1
}

get_enforcement() {
  if [ -f "$AUTOMATION_FILE" ]; then
    grep -E "^- preapproval_enforcement:" "$AUTOMATION_FILE" | head -n 1 \
      | sed -E "s/^- preapproval_enforcement:[[:space:]]*//" || true
  fi
}

warn_or_block() {
  local msg="$1"
  local enforcement="$2"
  mkdir -p "$(dirname "$WARN_FILE")"
  printf '%s [file-protection] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$msg" >> "$WARN_FILE"
  if [ "$enforcement" = "block" ]; then
    echo "파일 보호 정책: $msg" >&2
    exit 2
  fi
  echo "파일 보호 경고: $msg" >&2
}

if is_protected_policy_file "$FILE_PATH"; then
  enforcement="$(get_enforcement)"
  [ -z "$enforcement" ] && enforcement="report"
  warn_or_block "정책 파일 직접 수정 감지: $FILE_PATH (autonomy.md '사용자 확인 필요' 대상)" "$enforcement"
fi

exit 0
