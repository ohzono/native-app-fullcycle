#!/usr/bin/env bash
# scripts/test/check-task-spawn.test.sh
# scripts/check-task-spawn.sh の単体テスト
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$SCRIPT_DIR/check-task-spawn.sh"

if [[ ! -x "$SCRIPT" ]]; then
  echo "ERROR: $SCRIPT not found or not executable" >&2
  exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    FAIL=$((FAIL+1))
  fi
}

make_state() {
  # $1 = filepath, $2.. = JSON subIssue entries
  local file="$1"; shift
  local entries
  entries=$(IFS=,; echo "$*")
  printf '{"subIssues":[%s]}\n' "$entries" > "$file"
}

sub_issue() {
  # $1=number, $2=taskId, $3=outputFile, $4=status
  jq -n --argjson n "$1" --arg t "$2" --arg o "$3" --arg s "$4" \
    '{number: $n, taskId: $t, outputFile: $o, status: $s}'
}

run_script() {
  # $1 = state file ; SPAWN_CHECK_WAIT_SEC=0 でテスト高速化
  SPAWN_CHECK_WAIT_SEC=0 bash "$SCRIPT" --state "$1"
}

# ===== Tests =====

# Test: 空 subIssues
state="$TMPDIR/empty.json"
make_state "$state"
out=$(run_script "$state")
assert_eq "empty subIssues: healthy length 0" "0" "$(jq -r '.healthy | length' <<<"$out")"
assert_eq "empty subIssues: failed length 0" "0" "$(jq -r '.failed | length' <<<"$out")"
assert_eq "empty subIssues: not degraded" "false" "$(jq -r '.degraded // false' <<<"$out")"

# Test: progress 行を含む outputFile → healthy
state="$TMPDIR/healthy.json"
out_log="$TMPDIR/out_healthy.log"
echo '{"type":"progress","issue":101,"currentPhase":2}' > "$out_log"
make_state "$state" "$(sub_issue 101 "task_h" "$out_log" "running")"
out=$(run_script "$state")
assert_eq "healthy: 1 in healthy" "1" "$(jq -r '.healthy | length' <<<"$out")"
assert_eq "healthy: 0 in failed" "0" "$(jq -r '.failed | length' <<<"$out")"
assert_eq "healthy: issue number is 101" "101" "$(jq -r '.healthy[0]' <<<"$out")"

# Test: outputFile 不在 → failed with "outputFile missing"
state="$TMPDIR/missing.json"
missing_path="$TMPDIR/never_created.log"
make_state "$state" "$(sub_issue 102 "task_m" "$missing_path" "running")"
out=$(run_script "$state")
assert_eq "missing: 0 in healthy" "0" "$(jq -r '.healthy | length' <<<"$out")"
assert_eq "missing: 1 in failed" "1" "$(jq -r '.failed | length' <<<"$out")"
assert_eq "missing: reason matches" "true" \
  "$(jq -r '.failed[0].reason | contains("missing")' <<<"$out")"
assert_eq "missing: issue 102" "102" "$(jq -r '.failed[0].issue' <<<"$out")"

# Test: 0 バイト outputFile → failed with "empty"
state="$TMPDIR/empty_file.json"
empty_log="$TMPDIR/empty.log"
: > "$empty_log"
make_state "$state" "$(sub_issue 103 "task_e" "$empty_log" "running")"
out=$(run_script "$state")
assert_eq "empty file: 1 in failed" "1" "$(jq -r '.failed | length' <<<"$out")"
assert_eq "empty file: reason matches" "true" \
  "$(jq -r '.failed[0].reason | contains("empty")' <<<"$out")"

# Test: "failed to spawn" を含む outputFile → failed
state="$TMPDIR/kw.json"
kw_log="$TMPDIR/kw.log"
echo "starting agent" > "$kw_log"
echo "Failed to spawn isolation worker" >> "$kw_log"
make_state "$state" "$(sub_issue 104 "task_k" "$kw_log" "running")"
out=$(run_script "$state")
assert_eq "keyword: 1 in failed" "1" "$(jq -r '.failed | length' <<<"$out")"
assert_eq "keyword: reason mentions spawn error" "true" \
  "$(jq -r '.failed[0].reason | test("spawn error keyword"; "i")' <<<"$out")"

# Test: SPAWN_CHECK_PATTERNS で追加パターン
state="$TMPDIR/extra.json"
extra_log="$TMPDIR/extra.log"
echo "FATAL: my custom panic" > "$extra_log"
make_state "$state" "$(sub_issue 105 "task_x" "$extra_log" "running")"
out=$(SPAWN_CHECK_WAIT_SEC=0 SPAWN_CHECK_PATTERNS='my custom panic' bash "$SCRIPT" --state "$state")
assert_eq "extra pattern: 1 in failed" "1" "$(jq -r '.failed | length' <<<"$out")"

# Test: 待機開始時 0 バイト → 待機中に progress 出力 → healthy
state="$TMPDIR/race.json"
race_log="$TMPDIR/race.log"
: > "$race_log"
make_state "$state" "$(sub_issue 106 "task_r" "$race_log" "running")"

# バックグラウンドで 1 秒後に progress を書き込む
( sleep 1; echo '{"type":"progress","issue":106}' > "$race_log" ) &
bg_pid=$!

out=$(SPAWN_CHECK_WAIT_SEC=2 bash "$SCRIPT" --state "$state")
wait "$bg_pid"

assert_eq "race: 1 in healthy" "1" "$(jq -r '.healthy | length' <<<"$out")"
assert_eq "race: 0 in failed" "0" "$(jq -r '.failed | length' <<<"$out")"

# Test: 3 タスク、2 件 fail (空 + 不在)、1 件 healthy、1 件 spawn_failed (skip)
state="$TMPDIR/multi.json"
ok_log="$TMPDIR/multi_ok.log"
empty_log2="$TMPDIR/multi_empty.log"
missing_log="$TMPDIR/multi_missing.log"
echo '{"type":"progress"}' > "$ok_log"
: > "$empty_log2"
make_state "$state" \
  "$(sub_issue 201 "t1" "$ok_log" "running")" \
  "$(sub_issue 202 "t2" "$empty_log2" "running")" \
  "$(sub_issue 203 "t3" "$missing_log" "running")" \
  "$(sub_issue 204 "t4" "$ok_log" "spawn_failed")"
out=$(run_script "$state")
assert_eq "multi: 1 in healthy" "1" "$(jq -r '.healthy | length' <<<"$out")"
assert_eq "multi: 2 in failed" "2" "$(jq -r '.failed | length' <<<"$out")"
assert_eq "multi: spawn_failed not in failed" "false" \
  "$(jq -r '[.failed[].issue] | any(. == 204)' <<<"$out")"

# Test: jq が PATH に無い場合 → degraded mode
state="$TMPDIR/jq.json"
make_state "$state"
# macOS では /usr/bin/jq があるため /bin のみに絞る
out=$(PATH=/bin SPAWN_CHECK_WAIT_SEC=0 bash "$SCRIPT" --state "$state" 2>/dev/null) || true
if echo "$out" | grep -q '"degraded":true'; then
  echo "PASS: jq missing: degraded:true returned"
  PASS=$((PASS+1))
else
  echo "FAIL: jq missing: expected degraded:true, got: $out"
  FAIL=$((FAIL+1))
fi

# Test: SPAWN_CHECK_DEBUG=1 で stderr にデバッグログ + mtime 表示
state="$TMPDIR/debug.json"
dlog="$TMPDIR/debug.log"
echo '{"type":"progress"}' > "$dlog"
make_state "$state" "$(sub_issue 301 "td" "$dlog" "running")"
stderr_out=$(SPAWN_CHECK_WAIT_SEC=0 SPAWN_CHECK_DEBUG=1 bash "$SCRIPT" --state "$state" 2>&1 >/dev/null)
if echo "$stderr_out" | grep -q '\[DEBUG\]'; then
  echo "PASS: debug: stderr contains [DEBUG] tag"
  PASS=$((PASS+1))
else
  echo "FAIL: debug: no [DEBUG] in stderr"
  FAIL=$((FAIL+1))
fi
if echo "$stderr_out" | grep -qE 'mtime=[0-9]+'; then
  echo "PASS: debug: stderr shows mtime"
  PASS=$((PASS+1))
else
  echo "FAIL: debug: no mtime in stderr"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
