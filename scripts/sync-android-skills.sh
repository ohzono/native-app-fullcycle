#!/usr/bin/env bash
# Sync vendored subset of android/skills from upstream (Apache 2.0, Google LLC).
#
# 取り込み方式: vendored copy（git submodule ではない）。
# upstream の中から本プラグインがラッパー化している 6 skill のサブツリーのみを
# vendor/android-skills/ 配下に実ファイルとして複製する。これにより marketplace
# (github source) インストールでも確実に同梱され、submodule 初期化が不要になる。
#
# Usage:
#   ./scripts/sync-android-skills.sh            # PINNED_SHA を取り込む（再現性あり）
#   ./scripts/sync-android-skills.sh <git-ref>  # 指定 ref/SHA を取り込む（pin 更新時）
set -euo pipefail

REPO="android/skills"
# 取り込み対象を固定する pin。再現性・改竄検知のため main 追従ではなく SHA を既定にする。
PINNED_SHA="392fd3bcf28d25c890f48b20fd9a7f680d9bdc64"
REF="${1:-$PINNED_SHA}"
DEST="vendor/android-skills"

# ラッパー skill が参照する upstream サブツリー（NOTICE.md の対応表と一致させること）
SUBDIRS=(
  "build/agp/agp-9-upgrade"
  "jetpack-compose/migration/migrate-xml-views-to-jetpack-compose"
  "navigation/navigation-3"
  "performance/r8-analyzer"
  "play/play-billing-library-version-upgrade"
  "system/edge-to-edge"
)

# リポジトリルートで実行する前提（DEST は相対パス）
if [ ! -d "skills" ] || [ ! -d "scripts" ]; then
  echo "ERROR: リポジトリルートで実行してください" >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Fetching ${REPO}@${REF} ..."
git init -q "$TMPDIR/upstream"
(
  cd "$TMPDIR/upstream"
  git remote add origin "https://github.com/${REPO}.git"
  # SHA 指定でも取得できるよう fetch を使う。SHA 直接 fetch が不可な環境では
  # full clone へフォールバックして checkout する。
  if ! git fetch -q --depth=1 origin "$REF" 2>/dev/null; then
    echo "  shallow fetch by ref failed; falling back to full clone" >&2
    git fetch -q origin
  fi
  git checkout -q FETCH_HEAD 2>/dev/null || git checkout -q "$REF"
)
UPSTREAM_SHA="$(cd "$TMPDIR/upstream" && git rev-parse HEAD)"
echo "Upstream SHA: $UPSTREAM_SHA"

# 取り込み対象サブツリーの存在検証（pin 更新でリネームされたら気づけるように）
for d in "${SUBDIRS[@]}"; do
  if [ ! -d "$TMPDIR/upstream/$d" ]; then
    echo "ERROR: upstream に $d が見つかりません（ref=$REF）。パスのリネームを確認してください。" >&2
    exit 1
  fi
done

# 既存 vendor を破棄して必要サブツリーのみ再取り込み（不要物の蓄積を防ぐ）
rm -rf "$DEST"
mkdir -p "$DEST"
for d in "${SUBDIRS[@]}"; do
  mkdir -p "$DEST/$(dirname "$d")"
  cp -R "$TMPDIR/upstream/$d" "$DEST/$d"
done

# Apache 2.0 ライセンス本文を同梱（帰属要件）
cp "$TMPDIR/upstream/LICENSE.txt" "$DEST/LICENSE.txt"

cat > "$DEST/UPSTREAM.md" <<META
# Upstream

このディレクトリは外部プロジェクト android/skills から vendored copy として取り込んでいます。
\`vendor/android-skills/\` 配下のファイルは直接編集しないでください（このファイルを除く）。
更新は upstream で行い、\`scripts/sync-android-skills.sh\` を再実行してください。

- Source: https://github.com/${REPO}
- Ref: ${REF}
- Commit: ${UPSTREAM_SHA}
- License: Apache License 2.0 (see \`LICENSE.txt\`)
- Copyright: © Google LLC

## 取り込んでいるサブツリー（ラッパー skill と対応）

- \`build/agp/agp-9-upgrade\` → skills/android-agp-upgrade
- \`jetpack-compose/migration/migrate-xml-views-to-jetpack-compose\` → skills/android-compose-migration
- \`navigation/navigation-3\` → skills/android-navigation3
- \`performance/r8-analyzer\` → skills/android-r8-analyzer
- \`play/play-billing-library-version-upgrade\` → skills/android-play-billing
- \`system/edge-to-edge\` → skills/android-edge-to-edge
META

echo "Synced ${#SUBDIRS[@]} subtrees to $DEST (commit ${UPSTREAM_SHA:0:7})"
