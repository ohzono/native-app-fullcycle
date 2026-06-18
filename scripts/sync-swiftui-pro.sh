#!/usr/bin/env bash
# Sync vendored swiftui-pro skill from upstream twostraws/SwiftUI-Agent-Skill (MIT).
#
# 取り込み方式: vendored copy（git submodule ではない）。
# 再現性・改竄検知のため main 追従ではなく SHA を既定 pin にする。pin を更新する
# 場合のみ第1引数で ref/SHA を渡す。
#
# Usage:
#   ./scripts/sync-swiftui-pro.sh            # PINNED_SHA を取り込む（再現性あり）
#   ./scripts/sync-swiftui-pro.sh <git-ref>  # 指定 ref/SHA を取り込む（pin 更新時）
set -euo pipefail

REPO="twostraws/SwiftUI-Agent-Skill"
# 取り込み対象を固定する pin。再現性・改竄検知のため main 追従ではなく SHA を既定にする。
PINNED_SHA="61b74001b64b292da8397355464d7c8a4c2c7d89"
REF="${1:-$PINNED_SHA}"
DEST="skills/swiftui-pro"

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
ACTUAL_SHA="$(cd "$TMPDIR/upstream" && git rev-parse HEAD)"
echo "Upstream SHA: $ACTUAL_SHA"

# 改竄検知: REF が 40 桁 SHA の場合、checkout 後の実 SHA と照合する。
# upstream main の改竄/不正コミットが無検知で取り込まれるのを防ぐ。
if [[ "$REF" =~ ^[0-9a-f]{40}$ ]] && [ "$ACTUAL_SHA" != "$REF" ]; then
  echo "ERROR: checkout した SHA ($ACTUAL_SHA) が期待 SHA ($REF) と一致しません。" >&2
  echo "       upstream の改竄またはピンの取り違えの可能性があります。中止します。" >&2
  exit 1
fi

mkdir -p "$DEST"

# Mirror swiftui-pro/ contents into skills/swiftui-pro/ (preserving our attribution files).
# upstream の入れ子構造（新たに追加され得る .claude-plugin/ manifest や nested skills/）が
# 混入すると Claude Code のプラグインローダが予期せぬ plugin.json を拾うおそれがあるため除外する。
rsync -a --delete \
  --exclude 'UPSTREAM.md' \
  --exclude 'UPSTREAM_LICENSE' \
  --exclude '.claude-plugin/' \
  --exclude 'skills/' \
  "$TMPDIR/upstream/swiftui-pro/" "$DEST/"

cp "$TMPDIR/upstream/LICENSE" "$DEST/UPSTREAM_LICENSE"

# UPSTREAM.md は決定論的に生成する（再同期で差分が出ないよう実行時刻は記録しない）。
cat > "$DEST/UPSTREAM.md" <<META
# Upstream

This skill is vendored from an external project. Do not edit files under
\`skills/swiftui-pro/\` (other than this file and \`UPSTREAM_LICENSE\`)
directly — modify upstream and re-run \`scripts/sync-swiftui-pro.sh\`.

- Source: https://github.com/${REPO}
- Ref: ${REF}
- Commit: ${ACTUAL_SHA}
- License: MIT (see \`UPSTREAM_LICENSE\`)
- Author: Paul Hudson (@twostraws)
META

echo "Synced to $DEST (commit ${ACTUAL_SHA:0:7})"
