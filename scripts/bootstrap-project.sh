#!/bin/bash

set -euo pipefail

ROOT_DIR="."
RUN_ONBOARDING=1

for arg in "$@"; do
  case "$arg" in
    --skip-onboarding)
      RUN_ONBOARDING=0
      ;;
    *)
      ROOT_DIR="$arg"
      ;;
  esac
done

if [ ! -d "$ROOT_DIR" ]; then
  echo "bootstrap-project 실패: 디렉터리가 없습니다: $ROOT_DIR" >&2
  exit 2
fi

cd "$ROOT_DIR"

if [ ! -d ".claude" ] || [ ! -d ".devharness" ]; then
  echo "bootstrap-project 실패: .claude 또는 .devharness가 없습니다." >&2
  echo "먼저 GitHub Template(dev-harness)로 생성한 저장소에서 실행하세요." >&2
  exit 2
fi

if [ ! -x ".claude/hooks/run-project-onboarding.sh" ]; then
  chmod +x .claude/hooks/*.sh
fi

missing=0
for bin in jq rg; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "bootstrap-project 경고: '$bin' 명령을 찾지 못했습니다." >&2
    missing=1
  fi
done

if [ "$RUN_ONBOARDING" -eq 1 ]; then
  .claude/hooks/run-project-onboarding.sh
fi

echo
echo "bootstrap-project 완료"
echo "- 다음 단계: Claude에서 /init-project 실행"
if [ "$RUN_ONBOARDING" -eq 1 ]; then
  echo "- 완료 후 .claude/hooks/run-project-onboarding.sh 를 한 번 더 실행해 상태를 ready로 맞추세요"
fi

if [ "$missing" -eq 1 ]; then
  echo "- 참고: jq/rg 설치 후 다시 실행하면 품질 게이트/탐지 정확도가 좋아집니다"
fi

exit 0
