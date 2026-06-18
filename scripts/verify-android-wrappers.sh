#!/usr/bin/env bash
# android-* ラッパー skill が参照する vendor/android-skills/... のパスが、
# vendored copy 内に実在するかを検証する。upstream のリネームや pin 更新で
# 参照が切れた場合に CI で気づけるようにするための決定論的チェック。
#
# Usage: ./scripts/verify-android-wrappers.sh   （リポジトリルートで実行）
# Exit:  0 = すべての参照が実在 / 1 = 参照切れ or 参照を検出できず
set -uo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-$(pwd)}"
cd "$ROOT"

if [ ! -d "vendor/android-skills" ]; then
  echo "ERROR: vendor/android-skills が存在しません（vendored copy 未取得）。scripts/sync-android-skills.sh を実行してください。" >&2
  exit 1
fi

fail=0
checked=0

# 各 android-* ラッパー SKILL.md が参照する vendor/android-skills/... を抽出。
# ${CLAUDE_PLUGIN_ROOT}/ プレフィックスは無視し vendor/ からの相対で存在確認する。
while IFS= read -r path; do
  [ -z "$path" ] && continue
  checked=$((checked + 1))
  if [ -e "$path" ]; then
    echo "OK    $path"
  else
    echo "MISS  $path" >&2
    fail=1
  fi
done < <(grep -rhoE 'vendor/android-skills/[A-Za-z0-9._/-]+' skills/android-*/SKILL.md 2>/dev/null | sort -u)

if [ "$checked" -eq 0 ]; then
  echo "ERROR: ラッパー skill から vendor/android-skills/ への参照を1件も検出できませんでした。" >&2
  exit 1
fi

if [ "$fail" -eq 0 ]; then
  echo "----"
  echo "PASS: $checked 件の vendor 参照がすべて実在します。"
else
  echo "----" >&2
  echo "FAIL: 参照切れがあります（上記 MISS）。pin 更新や upstream リネームを確認してください。" >&2
fi
exit "$fail"
