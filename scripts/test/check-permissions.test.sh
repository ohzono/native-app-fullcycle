#!/usr/bin/env bash
# scripts/test/check-permissions.test.sh
# scripts/check-permissions.sh の単体テスト
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$SCRIPT_DIR/check-permissions.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ ! -x "$SCRIPT" ]]; then
  echo "ERROR: $SCRIPT not found or not executable" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not found; check-permissions.sh tests require python3"
  exit 0
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

write_settings() {
  # $1 = dir, $2 = allow 配列の中身（JSON 文字列のカンマ区切り）
  mkdir -p "$1/.claude"
  printf '{"permissions":{"allow":[%s]}}' "$2" > "$1/.claude/settings.json"
}

run_check() {
  # $1 = 検証対象ディレクトリ, $2.. = 追加引数（--parallel 等）。exit code を echo する。
  local dir="$1"; shift
  "$SCRIPT" --dir "$dir" "$@" >/dev/null 2>&1
  echo $?
}

# --- Case 1: settings.example.json（git/gh 個別列挙 + Write 全許可）→ 合格(0) ---
d1="$TMPDIR/example"; mkdir -p "$d1/.claude"
cp "$REPO_ROOT/.claude/settings.example.json" "$d1/.claude/settings.json"
assert_eq "settings.example.json は合格する" "0" "$(run_check "$d1")"

# --- Case 2: 空 allow → 不足(1) ---
d2="$TMPDIR/empty"
write_settings "$d2" ""
assert_eq "空 allow は不足で停止する" "1" "$(run_check "$d2")"

# --- Case 3: 包括許可 Bash(git:*)/Bash(gh:*) + 状態ファイル Write → 合格(0) ---
d3="$TMPDIR/blanket"
write_settings "$d3" '"Bash(git:*)","Bash(gh:*)","Write(.full-cycle-state.json)","Edit(.full-cycle-state.json)"'
assert_eq "包括許可は合格する" "0" "$(run_check "$d3")"

# --- Case 4: settings ファイル不在 → 検証不能(2) ---
d4="$TMPDIR/nosettings"; mkdir -p "$d4"
assert_eq "settings 不在は検証不能(2)" "2" "$(run_check "$d4")"

# --- Case 5: git のみ許可（gh 欠落）→ 不足(1) ---
d5="$TMPDIR/gitonly"
write_settings "$d5" '"Bash(git:*)","Write(.full-cycle-state.json)"'
assert_eq "gh 欠落は不足で停止する" "1" "$(run_check "$d5")"

# --- Case 6: Bash 全許可だが状態ファイル Write 欠落 → 不足(1) ---
d6="$TMPDIR/nowrite"
write_settings "$d6" '"Bash"'
assert_eq "状態ファイル Write 欠落は不足で停止する" "1" "$(run_check "$d6")"

# --- Case 7: --parallel 指定時に .parallel-...-state.json Write 欠落 → 不足(1) ---
d7="$TMPDIR/parallel-missing"
write_settings "$d7" '"Bash(git:*)","Bash(gh:*)","Write(.full-cycle-state.json)"'
assert_eq "--parallel なしなら合格" "0" "$(run_check "$d7")"
assert_eq "--parallel で parallel-state Write 欠落は不足" "1" "$(run_check "$d7" --parallel)"

# --- Case 8: git/gh を個別サブコマンドで列挙 + Write → 合格(0) ---
d8="$TMPDIR/enumerated"
write_settings "$d8" '"Bash(git add*)","Bash(git commit*)","Bash(git push*)","Bash(git fetch*)","Bash(git merge*)","Bash(git worktree*)","Bash(git rev-parse*)","Bash(git status*)","Bash(git diff*)","Bash(gh pr *)","Bash(gh issue *)","Bash(gh api *)","Bash(gh repo view*)","Bash(gh auth status*)","Write(.full-cycle-state.json)"'
assert_eq "個別サブコマンド列挙は合格する" "0" "$(run_check "$d8")"

# --- Case 9: 一部 git サブコマンドのみ（push 欠落）→ 不足(1) ---
d9="$TMPDIR/partial-git"
write_settings "$d9" '"Bash(git status*)","Bash(git diff*)","Bash(gh:*)","Write(.full-cycle-state.json)"'
assert_eq "git push 等の欠落は不足で停止する" "1" "$(run_check "$d9")"

# --- Case 10: worktree（.claude なし）から本体の .claude/settings.json を発見 → 合格(0) ---
# 本 PR の核心ロジック（git rev-parse --git-common-dir 経由で本体 .claude/ を探索）の回帰ガード。
# worktree 側に settings が無くても、本体ワーキングツリーの settings を発見できることを検証する。
if command -v git >/dev/null 2>&1; then
  mainrepo="$TMPDIR/mainrepo"
  mkdir -p "$mainrepo/.claude"
  ( cd "$mainrepo" \
      && git init -q \
      && git config user.email "t@example.com" \
      && git config user.name "t" \
      && git commit -q --allow-empty -m init )
  printf '{"permissions":{"allow":["Bash(git:*)","Bash(gh:*)","Write(.full-cycle-state.json)"]}}' \
    > "$mainrepo/.claude/settings.json"
  wt="$TMPDIR/wt-issue-1"
  ( cd "$mainrepo" && git worktree add -q "$wt" -b feat/issue-1 )
  # worktree 側には .claude/ を作らない（gitignore された settings.local.json を模擬）
  assert_eq "worktree から本体 .claude/ を発見して合格" "0" "$(run_check "$wt")"
else
  echo "SKIP: git not found; worktree discovery case skipped"
fi

echo ""
echo "Total: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
