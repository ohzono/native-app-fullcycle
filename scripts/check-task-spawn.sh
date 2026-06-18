#!/usr/bin/env bash
# scripts/check-task-spawn.sh
# Phase 2.5 spawn verification for /parallel-full-cycle
# See: docs/superpowers/specs/2026-05-15-spawn-check-design.md
set -uo pipefail

STATE_FILE=".parallel-full-cycle-state.json"
WAIT_SEC="${SPAWN_CHECK_WAIT_SEC:-15}"
DEBUG="${SPAWN_CHECK_DEBUG:-0}"
EXTRA_PATTERNS="${SPAWN_CHECK_PATTERNS:-}"

ERROR_PATTERNS='failed to spawn|isolation worktree creation failed|Error: spawn|worktree initialization failed'
if [[ -n "$EXTRA_PATTERNS" ]]; then
  ERROR_PATTERNS="${ERROR_PATTERNS}|${EXTRA_PATTERNS}"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state) STATE_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

debug() {
  [[ "$DEBUG" == "1" ]] && echo "[DEBUG] $*" >&2 || true
}

get_mtime() {
  local f="$1"
  if [[ ! -e "$f" ]]; then
    echo 0
    return
  fi
  stat -f "%m" "$f" 2>/dev/null || \
    stat -c "%Y" "$f" 2>/dev/null || \
    python3 -c 'import os,sys;print(int(os.stat(sys.argv[1]).st_mtime))' "$f" 2>/dev/null || \
    echo 0
}

if ! command -v jq >/dev/null 2>&1; then
  echo "WARN: jq not found, Phase 2.5 is no-op" >&2
  # jq 不在では JSON 生成できないので素の文字列で出力
  printf '%s\n' '{"healthy":[],"failed":[],"degraded":true}'
  exit 0
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: state file not found: $STATE_FILE" >&2
  exit 1
fi

debug "state file: $STATE_FILE"
debug "wait sec: $WAIT_SEC"

sleep "$WAIT_SEC"

healthy=()
failed_entries=()

while IFS=$'\t' read -r issue task_id output_file status; do
  if [[ "$status" == "spawn_failed" || "$status" == "success" || "$status" == "error" || "$status" == "stopped" ]]; then
    debug "issue $issue: skipping (status=$status)"
    continue
  fi

  debug "issue $issue: checking $output_file"

  if [[ "$DEBUG" == "1" && -e "$output_file" ]]; then
    debug "issue $issue: outputFile mtime=$(get_mtime "$output_file")"
  fi

  # progress 行を含む → healthy
  if [[ -f "$output_file" ]] && grep -q '"type":"progress"' "$output_file" 2>/dev/null; then
    debug "issue $issue: healthy (progress line found)"
    healthy+=("$issue")
    continue
  fi

  # outputFile 不在
  if [[ ! -f "$output_file" ]]; then
    debug "issue $issue: outputFile missing"
    failed_entries+=("$(jq -n \
      --argjson i "$issue" \
      --arg r "outputFile missing after ${WAIT_SEC}s" \
      --arg t "$task_id" \
      '{issue: $i, reason: $r, taskId: $t}')")
    continue
  fi

  # outputFile が 0 バイト
  if [[ ! -s "$output_file" ]]; then
    debug "issue $issue: outputFile empty"
    failed_entries+=("$(jq -n \
      --argjson i "$issue" \
      --arg r "outputFile empty after ${WAIT_SEC}s" \
      --arg t "$task_id" \
      '{issue: $i, reason: $r, taskId: $t}')")
    continue
  fi

  # エラーキーワード検出
  if grep -iE "$ERROR_PATTERNS" "$output_file" >/dev/null 2>&1; then
    matched=$(grep -iEo "$ERROR_PATTERNS" "$output_file" | head -n 1)
    debug "issue $issue: spawn error keyword detected: $matched"
    failed_entries+=("$(jq -n \
      --argjson i "$issue" \
      --arg r "spawn error keyword detected: ${matched}" \
      --arg t "$task_id" \
      '{issue: $i, reason: $r, taskId: $t}')")
    continue
  fi

  # ここまで来たら、ファイル存在 + 非空 + キーワードなし + progress なし
  # → 進行中だが progress 形式ではない出力。healthy 扱い
  debug "issue $issue: healthy (non-empty output, no error keyword)"
  healthy+=("$issue")
done < <(jq -r '.subIssues[] | [(.number|tostring), (.taskId // ""), (.outputFile // ""), (.status // "")] | @tsv' "$STATE_FILE")

if [[ ${#healthy[@]} -eq 0 ]]; then
  healthy_json='[]'
else
  healthy_json=$(printf '%s\n' "${healthy[@]}" | jq -R 'tonumber' | jq -s .)
fi
if [[ ${#failed_entries[@]} -eq 0 ]]; then
  failed_json='[]'
else
  failed_json="[$(IFS=,; echo "${failed_entries[*]}")]"
fi

jq -n --argjson h "$healthy_json" --argjson f "$failed_json" \
  '{healthy: $h, failed: $f}'
