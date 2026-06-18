#!/usr/bin/env bash
# scripts/validate-fullcycle-schema.sh
# フルサイクル状態機械の正本とドキュメント・読み手の整合を検証する。
# 使い方: validate-fullcycle-schema.sh [REPO_ROOT]
set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCHEMA_DIR="${ROOT}/commands/full-cycle-phases/_schema"
STATE="${SCHEMA_DIR}/state-schema.yaml"
FLOW="${SCHEMA_DIR}/phase-flow.yaml"
errors=0
err() { echo "ERROR: $*" >&2; errors=$((errors+1)); }

command -v yq >/dev/null 2>&1 || { echo "yq required" >&2; exit 2; }
[ -f "${STATE}" ] || err "missing ${STATE}"
[ -f "${FLOW}" ]  || err "missing ${FLOW}"
[ "${errors}" -eq 0 ] || exit 1

# (A) 正本がパースできる
yq '.' "${STATE}" >/dev/null 2>&1 || err "state-schema.yaml parse error"
yq '.' "${FLOW}"  >/dev/null 2>&1 || err "phase-flow.yaml parse error"

# (B) reader 整合: status/cleanup が読むフィールドのトップレベル名が schema に存在
known="$(yq -r '.fields | keys | .[]' "${STATE}" 2>/dev/null)"
for reader in status cleanup; do
  while IFS= read -r f; do
    [ -z "${f}" ] && continue
    top="${f%%.*}"
    echo "${known}" | grep -qx "${top}" || err "unknown reader field (${reader}): ${f}"
  done < <(yq -r ".readers.${reader}[]" "${STATE}" 2>/dev/null)
done

# (C) drift lint: フェーズ/コマンドに状態機械4ループ（codeReview/designReview/techAssess/
#     fixToMerge）の上限がハードコードで残っていないか。残っていれば loops を参照すべき。
#     判定: 「ループ上限の言い回し or bash 数値比較」の行で、ポーリング/タイムアウト等の
#     別ループでないもの。正本参照（loops.）の行でも数値が同居していれば drift とみなす
#     （参照行に数値を書くこと自体が drift の温床なため）。各種比較演算子・最大N回表現を網羅。
#     注: マルチバイト文字「範囲」(例 全角数字レンジ) は C locale の grep で不正となり
#     パターン全体が無効化されるため使わない。日本語リテラルは byte 一致で C locale でも動く。
#     注: bash 数値比較は 1 以上のみを上限とみなす（`-eq 0` 等の「空集合 / 0 件」判定は
#     ループ上限ではないため除外。ループ上限は必ず 1 以上である前提）。
DRIFT_RE='最大[[:space:]]*[0-9]+(回|ラウンド)|[0-9]+(回|ラウンド)(に達|まで|超過|を超)|[0-9]+[[:space:]]*回[[:space:]]*連続|-ge[[:space:]]+[1-9]|-gt[[:space:]]+[1-9]|-eq[[:space:]]+[1-9]|>=[[:space:]]*[1-9]'
EXCLUDE_RE='ポーリング|ポール|poll|秒[[:space:]]*×|秒×|heartbeat|タイムアウト|timeout'
while IFS= read -r mdfile; do
  [ -z "${mdfile}" ] && continue
  hits="$(grep -nE "${DRIFT_RE}" "${mdfile}" | grep -vE "${EXCLUDE_RE}")"
  if [ -n "${hits}" ]; then
    err "hardcoded loop limit in $(basename "${mdfile}") — phase-flow.yaml loops を参照すること:"
    echo "${hits}" | sed 's/^/    /' >&2
  fi
done < <(find "${ROOT}/commands" \( -name 'phase-*.md' -o -name 'full-cycle-*.md' -o -name 'parallel-full-cycle.md' \) 2>/dev/null)

# (D) 内部整合: phase-flow の writes に現れるフィールドの top-level が schema に存在
allknown="$(printf '%s\n' "${known}" | sort -u)"
while IFS= read -r w; do
  [ -z "${w}" ] && continue
  top="${w%%.*}"
  echo "${allknown}" | grep -qx "${top}" || err "phase-flow writes unknown field: ${w}"
done < <(yq -r '.phases[].writes[]?' "${FLOW}" 2>/dev/null | sort -u)

# (E) 廃止フィールド名ガード: deprecatedFields が commands/ と status/cleanup スキルに
#     出現したら drift（#30 回帰防止）。
while IFS= read -r dep; do
  [ -z "${dep}" ] && continue
  hits="$(grep -rnE "\b${dep}\b" \
    "${ROOT}/commands" \
    "${ROOT}/skills/status" \
    "${ROOT}/skills/cleanup" 2>/dev/null \
    | grep -v '_schema/state-schema.yaml')"
  if [ -n "${hits}" ]; then
    err "deprecated field '${dep}' used — state-schema.yaml の正準名を使うこと:"
    echo "${hits}" | sed 's/^/    /' >&2
  fi
done < <(yq -r '.deprecatedFields[]?' "${STATE}" 2>/dev/null)

# (F) 初期化値の整合: テンプレート JSON と phase-00 の初期化 cat ブロックの
#     top-level フィールド集合が state-schema.yaml の fields と一致するか
#     （新フィールド追加時に初期化側の stale 化を検出する。単一真実源の保証）。
schema_fields="$(yq -r '.fields | keys | .[]' "${STATE}" 2>/dev/null | sort -u)"

# check_field_set <label> <newline-separated-keys>
# 引数渡し（パイプにしないこと: パイプ末尾はサブシェルで errors 増分が親に伝播しない）
check_field_set() {
  local label="$1" actual d
  actual="$(printf '%s\n' "$2" | sort -u)"
  d="$(diff <(printf '%s\n' "${schema_fields}") <(printf '%s\n' "${actual}"))"
  if [ -n "${d}" ]; then
    err "init field-set drifted from state-schema.yaml fields (${label}):"
    echo "${d}" | sed 's/^/    /' >&2
  fi
}

if command -v jq >/dev/null 2>&1; then
  tmpl="${ROOT}/templates/kmp-ios-android/.full-cycle-state.template.json"
  if [ -f "${tmpl}" ]; then
    check_field_set "template" "$(jq -r 'keys[]' "${tmpl}" 2>/dev/null)"
  fi

  # phase-00 の `cat > ... <<EOF { ... } EOF` 内 JSON を抽出して照合
  p00="${ROOT}/commands/full-cycle-phases/block-a/phase-00-worktree.md"
  if [ -f "${p00}" ]; then
    # bash 変数 ${VAR} を 0 に置換して有効な JSON にしてから照合
    init_json="$(awk '/cat > .*full-cycle-state\.json.*<<EOF/{f=1;next} f&&/^EOF$/{f=0} f' "${p00}" \
      | sed 's/\${[A-Za-z_][A-Za-z0-9_]*}/0/g')"
    if [ -n "${init_json}" ]; then
      check_field_set "phase-00 init" "$(printf '%s\n' "${init_json}" | jq -r 'keys[]' 2>/dev/null)"
    fi
  fi
fi

if [ "${errors}" -eq 0 ]; then
  echo "OK: fullcycle schema consistent"
  exit 0
else
  exit 1
fi
