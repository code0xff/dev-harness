#!/bin/bash

set -euo pipefail

AUTOMATION_FILE=".claude/project-automation.md"

if [ ! -f "$AUTOMATION_FILE" ]; then
  echo "자동 감지 실패: $AUTOMATION_FILE 파일이 없습니다." >&2
  exit 2
fi

set_key() {
  local key="$1"
  local value="$2"
  awk -v key="$key" -v value="$value" '
    BEGIN { updated = 0 }
    $0 ~ "^- " key ":" {
      print "- " key ": " value
      updated = 1
      next
    }
    { print }
    END {
      if (updated == 0) {
        print "- " key ": " value
      }
    }
  ' "$AUTOMATION_FILE" > "${AUTOMATION_FILE}.tmp"
  mv "${AUTOMATION_FILE}.tmp" "$AUTOMATION_FILE"
}

has_make_target() {
  local target="$1"
  [ -f Makefile ] && grep -Eq "^${target}:" Makefile
}

detect_from_make() {
  local lint="unset"
  local build="unset"
  local test="unset"

  has_make_target lint && lint="make lint"
  has_make_target build && build="make build"
  has_make_target test && test="make test"

  echo "$lint|$build|$test"
}

detect_from_node() {
  local lint="unset"
  local build="unset"
  local test="unset"

  if [ -f package.json ] && command -v jq >/dev/null 2>&1; then
    jq -e '.scripts.lint' package.json >/dev/null 2>&1 && lint="npm run lint"
    jq -e '.scripts.build' package.json >/dev/null 2>&1 && build="npm run build"
    jq -e '.scripts.test' package.json >/dev/null 2>&1 && test="npm test"
  fi

  echo "$lint|$build|$test"
}

detect_from_python() {
  local lint="unset"
  local build="unset"
  local test="unset"

  if [ -f pyproject.toml ]; then
    lint="ruff check ."
    build="python -m build"
    test="pytest -q"
  fi

  echo "$lint|$build|$test"
}

detect_from_go() {
  local lint="unset"
  local build="unset"
  local test="unset"

  if [ -f go.mod ]; then
    lint="go vet ./..."
    build="go build ./..."
    test="go test ./..."
  fi

  echo "$lint|$build|$test"
}

detect_from_rust() {
  local lint="unset"
  local build="unset"
  local test="unset"

  if [ -f Cargo.toml ]; then
    lint="cargo clippy --all-targets --all-features -- -D warnings"
    build="cargo build --all-targets"
    test="cargo test --all-targets"
  fi

  echo "$lint|$build|$test"
}

choose_first_non_unset() {
  local current="$1"
  local candidate="$2"
  if [ "$current" = "unset" ] && [ "$candidate" != "unset" ]; then
    echo "$candidate"
  else
    echo "$current"
  fi
}

lint_cmd="unset"
build_cmd="unset"
test_cmd="unset"

for detector in detect_from_make detect_from_node detect_from_python detect_from_go detect_from_rust; do
  IFS='|' read -r d_lint d_build d_test <<< "$($detector)"
  lint_cmd="$(choose_first_non_unset "$lint_cmd" "$d_lint")"
  build_cmd="$(choose_first_non_unset "$build_cmd" "$d_build")"
  test_cmd="$(choose_first_non_unset "$test_cmd" "$d_test")"
done

set_key "lint_cmd" "$lint_cmd"
set_key "build_cmd" "$build_cmd"
set_key "test_cmd" "$test_cmd"

echo "자동 감지 완료:"
echo "- lint_cmd: $lint_cmd"
echo "- build_cmd: $build_cmd"
echo "- test_cmd: $test_cmd"
