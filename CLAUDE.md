# CLAUDE.md

## プラグイン概要

モバイル開発（iOS/Android）向けのフルサイクル開発プラグイン。GitHub Issue を起点に、仕様チェックからPR作成・レビューまでを自動化します。

## 構造

```
native-app-fullcycle/
├── .claude-plugin/plugin.json    # プラグインマニフェスト
├── agents/                        # 8つの専門エージェント
├── skills/                        # 25のスキル（10個はユーザー起動可能）
├── commands/                      # 5つのフルサイクルコマンド + フェーズファイル
│   └── full-cycle-phases/         # 21のフェーズ詳細定義
│       ├── block-a/               # 計画（Phase 0-7）
│       ├── block-b/               # 実装（Phase 8-11）
│       └── block-c/               # レビュー（Phase 12-20）
├── templates/                     # PRテンプレート
└── vendor/                        # 外部資産の vendored copy（実ファイル同梱）
    └── android-skills/            # Google 公式 android/skills（6サブツリーをSHA pinで同梱）
```

## プラグイン開発ガイドライン

### エージェント追加
1. `agents/` に新しい `.md` ファイルを作成（YAML frontmatter + 役割定義）
2. `plugin.json` の `agents` 配列に追加
3. 必要なツールとスキルの関連を定義

**skills 整合ルール（三者一致）**: agent の frontmatter `skills:` に名前を宣言したら、(1) `tools:` に `Skill` を必ず付与し、(2) 本文に「その skill を Skill tool で参照する」活用導線を書く。宣言した skill 名は `plugin.json` の登録 skill（`./skills/<name>`）に実在するものだけを使う。`skills:` 宣言 ⟺ `tools:` の `Skill` ⟺ 本文参照 の三者を常に一致させる。

### スキル追加
1. `skills/{skill-name}/SKILL.md` を作成
2. `plugin.json` の `skills` 配列に追加

### コマンド追加
1. `commands/` に新しい `.md` ファイルを作成（YAML frontmatter + 実行手順）
2. `plugin.json` の `commands` 配列に追加

### バージョニング
セマンティックバージョニングに従う: MAJOR.MINOR.PATCH

判断基準:
| 変更種別 | bump レベル |
|---|---|
| 新規 skill / agent / command の追加 | **MINOR** |
| 既存 skill / agent の振る舞いを大きく変える更新（フロントマター変更、デフォルト動作変更等） | **MINOR** |
| 既存 skill / agent / command の文言更新・小幅な拡張・誤記修正 | **PATCH** |
| 既存 skill の削除、フロントマター仕様変更で利用側を壊す変更 | **MAJOR** |
| ドキュメント / README / CLAUDE.md のみの更新 | bump 不要（PATCH でも可） |

bump タイミング: PR を merge する直前に `plugin.json` の `version` を更新。複数 PR が並行している場合は merge 時に conflict を解消して連番を維持する。

## ベンダリングされた外部スキル

一部のスキルは外部リポジトリから取り込んでおり、`scripts/sync-*.sh` で同期する。
これらは編集禁止（編集する場合は upstream で行い、再同期する）。

| スキル | 取り込み方式 | Upstream | License | Author |
|--------|-------------|----------|---------|--------|
| `skills/swiftui-pro` | vendored copy（SHA pin） | [twostraws/SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill) | MIT | Paul Hudson |
| `vendor/android-skills/*` | vendored copy（SHA pin） | [android/skills](https://github.com/android/skills) | Apache 2.0 | Google LLC |

いずれも **vendored copy**（実ファイル同梱）であり、git submodule は使用しない。marketplace の
github source インストールでもそのまま同梱されるため、submodule 初期化は不要。

同期方法:
```bash
# SwiftUI-Agent-Skill（PINNED_SHA を既定にした固定取り込み。再現性・改竄検知あり）
./scripts/sync-swiftui-pro.sh             # PINNED_SHA を取り込む（再現性あり）
./scripts/sync-swiftui-pro.sh <git-ref>   # pin を更新する場合に ref/SHA を指定

# android/skills（ラッパーが参照する 6 サブツリーのみを SHA pin で取り込む）
./scripts/sync-android-skills.sh          # PINNED_SHA を取り込む（再現性あり）
./scripts/sync-android-skills.sh <git-ref> # pin を更新する場合に ref/SHA を指定
```

android/skills からは以下をラッパー skill として `plugin.json` に登録（本体は
`${CLAUDE_PLUGIN_ROOT}/vendor/android-skills/...` を Read 指示で参照する。CWD 非依存）:
- `android-agp-upgrade` / `android-compose-migration` / `android-navigation3`
- `android-r8-analyzer` / `android-play-billing` / `android-edge-to-edge`

pin（取り込み SHA）を更新したら `scripts/verify-android-wrappers.sh` で 6 ラッパーの
参照パスが vendor 配下に実在するか検証すること。

`sync-swiftui-pro.sh` も同様に `PINNED_SHA` 固定で、第1引数に ref/SHA を渡したときのみ
pin を上書きする。引数が 40 桁 SHA の場合は checkout 後に実 SHA と照合し、不一致なら
中止する（upstream main の改竄/不正コミットの無検知取り込みを防ぐ）。upstream の
入れ子 `.claude-plugin/` や nested `skills/` は rsync で除外するため vendored 本体には
混入しない。pin を更新する前に `rsync -n`（dry-run）で取り込み対象を確認すると安全:

```bash
# 取り込み予定のファイル一覧を確認（実際にはコピーしない）
TMP="$(mktemp -d)"; cd "$TMP" && git clone --quiet --depth=1 \
  https://github.com/twostraws/SwiftUI-Agent-Skill.git upstream && cd -
rsync -an --out-format='%n' --exclude '.claude-plugin/' --exclude 'skills/' \
  "$TMP/upstream/swiftui-pro/" /tmp/_swiftui_pro_dryrun/
rm -rf "$TMP"
```

iOS の SwiftUI / Swift Concurrency に関するレビューや実装時は `swiftui-pro` スキルを優先的に使用する。
