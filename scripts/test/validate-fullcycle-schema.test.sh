#!/usr/bin/env bash
# scripts/test/validate-fullcycle-schema.test.sh
# scripts/validate-fullcycle-schema.sh の単体テスト
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="${SCRIPT_DIR}/validate-fullcycle-schema.sh"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -x "${VALIDATOR}" ]]; then
  echo "ERROR: ${VALIDATOR} not found or not executable" >&2
  exit 1
fi

PASS=0
FAIL=0
ok() { echo "PASS: $1"; PASS=$((PASS+1)); }
ng() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# 1. 正常系: リポジトリ現状で exit 0
if "${VALIDATOR}" "${ROOT}" >/dev/null 2>&1; then
  ok "valid repo passes"
else
  ng "valid repo should pass"
fi

# 2. status の reader 名がすべて schema に存在する（#30 回帰防止）
out="$("${VALIDATOR}" "${ROOT}" 2>&1)"
if ! echo "${out}" | grep -qi "unknown reader field"; then
  ok "no unknown reader field"
else
  ng "reader field mismatch detected"
fi

# 以降の drift テストは作業用コピーを使う。すべて共通の親 tmp 配下に作り trap で一括削除
BASE_TMP="$(mktemp -d)"
trap 'rm -rf "${BASE_TMP}"' EXIT
fresh_copy() { local d="${BASE_TMP}/$1"; mkdir -p "${d}"; cp -R "${ROOT}/." "${d}/"; echo "${d}"; }

# 3. drift lint: フェーズに裸のループ数値が混入したら検出する
d="$(fresh_copy t3)"
printf '\nreviewLoopCount -ge 3\n' >> "${d}/commands/full-cycle-phases/block-c/phase-14-fix.md"
if ! "${VALIDATOR}" "${d}" >/dev/null 2>&1; then ok "hardcoded loop number is rejected"; else ng "hardcoded loop number should fail"; fi

# 4. drift lint: 正本参照（loops.）と裸の数値が同一行に同居しても検出する（回帰防止）
d="$(fresh_copy t4)"
printf '\n上限は最大3回まで（loops.codeReview を参照）\n' >> "${d}/commands/full-cycle-phases/block-c/phase-14-fix.md"
if ! "${VALIDATOR}" "${d}" >/dev/null 2>&1; then ok "number on a loops. reference line is rejected"; else ng "number co-located with loops. should still fail"; fi

# 5. drift lint: -eq 比較もカバー（全角数字は C locale 制約のため非対応 — validate-fullcycle-schema.sh のコメント参照）
d="$(fresh_copy t5)"
printf '\nif [ "$N" -eq 5 ]; then : ; fi\n' >> "${d}/commands/full-cycle-phases/block-c/phase-19-fix-to-merge.md"
if ! "${VALIDATOR}" "${d}" >/dev/null 2>&1; then ok "-eq comparison is rejected"; else ng "-eq comparison should fail"; fi

# 6. drift lint: CI リトライの「N回連続」ハードコードを検出する
d="$(fresh_copy t6)"
printf '\nビルドが3回連続で失敗したら停止\n' >> "${d}/commands/parallel-full-cycle.md"
if ! "${VALIDATOR}" "${d}" >/dev/null 2>&1; then ok "hardcoded 'N回連続' is rejected"; else ng "'N回連続' should fail"; fi

# 6b. drift lint: 0 件判定（空集合 / 空リポジトリ）の -eq 0 は上限ではないので誤検知しない
d="$(fresh_copy t6b)"
printf '\nif [ "${TRACKED_COUNT}" -eq 0 ]; then : ; fi\n' >> "${d}/commands/full-cycle-phases/block-a/phase-00-worktree.md"
if "${VALIDATOR}" "${d}" >/dev/null 2>&1; then ok "-eq 0 (empty-set check) is not flagged"; else ng "-eq 0 should not be flagged as a loop limit"; fi

# 7. 初期化整合: テンプレート JSON に schema 未定義フィールドが混入したら検出する
d="$(fresh_copy t7)"
tmpl="${d}/templates/kmp-ios-android/.full-cycle-state.template.json"
jq '. + {bogusField: 1}' "${tmpl}" > "${tmpl}.new" && mv "${tmpl}.new" "${tmpl}"
if ! "${VALIDATOR}" "${d}" >/dev/null 2>&1; then ok "template field drift is rejected"; else ng "template field drift should fail"; fi

echo "PASS=${PASS} FAIL=${FAIL}"
[[ "${FAIL}" -eq 0 ]]
