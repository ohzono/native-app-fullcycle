#!/bin/bash
# check-permissions.sh — フルサイクル開発に必要なコマンド許可が
# `.claude/settings.json` / `.claude/settings.local.json` で事前許可されているか検証する。
#
# これは **read-only** の検証スクリプトであり、settings ファイルは一切編集しない
# （「settings.local.json は自動編集しない」という Phase 1 の方針を維持する）。
#
# 検証する理由（#52）:
#   parallel/background で spawn された orchestrator や、その配下の Task は
#   対話的な許可プロンプトに応答できないため、未許可の `git push` / `gh pr create`
#   は自動拒否されて詰む。background で詰む前に、事前許可の有無をここで早期検出する。
#
# 検証対象:
#   - git の必須サブコマンド許可（add/commit/push/fetch/merge/worktree/rev-parse/status/diff）
#   - gh の必須サブコマンド許可（pr/issue/api/repo/auth）
#   - 状態ファイルへの Write 許可（.full-cycle-state.json / 任意で .parallel-full-cycle-state.json）
#
# 注: permissions.allow のみを検証する（deny は見ない）。allow でカバーされたサブコマンドが
#     deny で部分的にブロックされていても「許可あり」と判定する点に注意
#     （フルサイクルの正常系コマンドは deny に触れない前提）。
#
# 包括許可（`Bash(git:*)` / `Bash(git *)`）でも、個別許可（`Bash(git push*)` 等の列挙）でも
# カバーされていれば合格と判定する。
#
# Usage:
#   bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-permissions.sh" [--dir <root>] [--parallel] [--json]
#
#   --dir <root>   検証する settings を探す基準ディレクトリ（省略時は cwd）。
#                  worktree 下では cwd に加えてメインのワーキングツリーも自動で候補に含める。
#   --parallel     並行フルサイクル用。.parallel-full-cycle-state.json の Write 許可も必須にする。
#   --json         結果を JSON で出力する（既定は人間可読テキスト）。
#
# Exit codes:
#   0  必要な許可がすべて揃っている
#   1  許可が不足している（不足項目を出力）— 呼び出し側は停止する
#   2  検証不能（settings ファイル不在 / python3 不在）— 呼び出し側は警告扱いで継続可
set -eu

BASE_DIR="${PWD}"
WANT_PARALLEL=0
OUT_JSON=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) BASE_DIR="$2"; shift 2 ;;
    --parallel) WANT_PARALLEL=1; shift ;;
    --json) OUT_JSON=1; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# 検証対象ディレクトリ: 基準ディレクトリ + （worktree の場合）メインのワーキングツリー。
# settings.local.json は通常 .gitignore されており worktree には存在しないため、
# メインルートの .claude/ も併せて参照する。
DIRS="${BASE_DIR}"
COMMON_GIT="$(cd "${BASE_DIR}" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "${COMMON_GIT}" ]; then
  # --git-common-dir はメインの .git を指す（絶対/相対の両方を返しうるため BASE_DIR を起点に解決する）。
  # その親がメインのワーキングツリー。
  COMMON_ABS="$(cd "${BASE_DIR}" && cd "$(dirname "${COMMON_GIT}")" 2>/dev/null && pwd || true)"
  if [ -n "${COMMON_ABS}" ] && [ "${COMMON_ABS}" != "${BASE_DIR}" ]; then
    DIRS="${DIRS}
${COMMON_ABS}"
  fi
fi

if ! command -v python3 >/dev/null 2>&1; then
  if [ "${OUT_JSON}" -eq 1 ]; then
    echo '{"status":"unverifiable","reason":"python3 not found"}'
  else
    echo "⚠️  権限検証をスキップ: python3 が見つかりません（手動で settings の git/gh 許可を確認してください）"
  fi
  exit 2
fi

CHECK_PARALLEL="${WANT_PARALLEL}" CHECK_JSON="${OUT_JSON}" CHECK_DIRS="${DIRS}" \
python3 - <<'PY'
import json, os, sys

dirs = [d for d in os.environ.get("CHECK_DIRS", "").splitlines() if d.strip()]
want_parallel = os.environ.get("CHECK_PARALLEL") == "1"
out_json = os.environ.get("CHECK_JSON") == "1"

allows = []
found_settings = False
seen = set()
for d in dirs:
    for name in (".claude/settings.json", ".claude/settings.local.json"):
        path = os.path.join(d, name)
        rp = os.path.realpath(path)
        if rp in seen:
            continue
        seen.add(rp)
        if os.path.exists(path):
            found_settings = True
            try:
                with open(path) as fh:
                    data = json.load(fh)
            except Exception:
                continue
            perms = (data.get("permissions") or {})
            for a in (perms.get("allow") or []):
                if isinstance(a, str):
                    allows.append(a)

if not found_settings:
    if out_json:
        print('{"status":"unverifiable","reason":"no settings file"}')
    else:
        print("⚠️  権限検証をスキップ: .claude/settings.json / settings.local.json が見つかりません")
    sys.exit(2)

def bash_inner(a):
    """`Bash(<inner>)` の inner を返す。Bash 系でなければ None。"""
    if a == "Bash":
        return ""  # 全 Bash 許可
    if a.startswith("Bash(") and a.endswith(")"):
        return a[5:-1].strip()
    return None

def covers_bash(tool, sub):
    """tool（git/gh）の sub サブコマンドが allow のいずれかでカバーされるか。"""
    blanket = {tool, tool + "*", tool + ":*", tool + " *", tool + ":", tool + " "}
    for a in allows:
        inner = bash_inner(a)
        if inner is None:
            continue
        if inner == "":          # `Bash` 全許可
            return True
        if inner in ("*", "**"):  # `Bash(*)`
            return True
        if inner in blanket:      # `Bash(git:*)` / `Bash(git *)` 等の包括許可
            return True
        for sep in (":", " "):
            pre = tool + sep
            if inner.startswith(pre):
                rest = inner[len(pre):].strip()
                parts = rest.split()
                base = (parts[0] if parts else "").rstrip("*")
                if base == "":        # `Bash(git )` 相当 → 包括扱い
                    return True
                if base == sub:       # `Bash(git push*)` → push をカバー
                    return True
    return False

def covers_write(filename):
    """状態ファイル filename への Write が許可されているか。"""
    for a in allows:
        if a in ("Write", "Edit", "Write(*)", "Edit(*)"):
            return True
        for tool in ("Write", "Edit"):
            pre = tool + "("
            if a.startswith(pre) and a.endswith(")"):
                inner = a[len(pre):-1].strip()
                if inner in ("*", filename, "./" + filename):
                    return True
    return False

GIT_SUBS = ["add", "commit", "push", "fetch", "merge", "worktree", "rev-parse", "status", "diff"]
GH_SUBS = ["pr", "issue", "api", "repo", "auth"]

missing = []

git_missing = [s for s in GIT_SUBS if not covers_bash("git", s)]
gh_missing = [s for s in GH_SUBS if not covers_bash("gh", s)]

if git_missing:
    missing.append("Bash(git:*)  ← git " + "/".join(git_missing) + " が未許可")
if gh_missing:
    missing.append("Bash(gh:*)  ← gh " + "/".join(gh_missing) + " が未許可")
if not covers_write(".full-cycle-state.json"):
    missing.append("Write(.full-cycle-state.json)")
if want_parallel and not covers_write(".parallel-full-cycle-state.json"):
    missing.append("Write(.parallel-full-cycle-state.json)")

if out_json:
    print(json.dumps({
        "status": "ok" if not missing else "insufficient",
        "missing": missing,
    }, ensure_ascii=False))
else:
    if not missing:
        print("✅ 権限OK: git / gh / 状態ファイル Write の事前許可を確認しました")
    else:
        print("❌ 権限不足: 以下を .claude/settings.json の permissions.allow に追加してください")
        for m in missing:
            print("   - " + m)
        print("")
        print("   推奨: プラグイン同梱の .claude/settings.example.json 全体をコピーする")
        print("   （allow と、破壊的操作をガードする deny がセットになっています）")
        print("")
        print("   allow のみ個別追記する場合（最小構成）:")
        print('   { "permissions": { "allow": [')
        print('     "Bash(git:*)", "Bash(gh:*)",')
        print('     "Write(.full-cycle-state.json)", "Edit(.full-cycle-state.json)"' +
              (',' if want_parallel else ''))
        if want_parallel:
            print('     "Write(.parallel-full-cycle-state.json)", "Edit(.parallel-full-cycle-state.json)"')
        print('   ] } }')
        print("")
        print("   ⚠️ Bash(git:*) / Bash(gh:*) は包括許可です。deny を設定しない場合、")
        print("      git push --force / git reset --hard / gh pr merge 等の破壊的コマンドも")
        print("      無確認で実行可能になります。settings.example.json の deny セットを併用してください。")

sys.exit(0 if not missing else 1)
PY
