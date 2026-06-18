# コントリビューションガイド

`native-app-fullcycle` への貢献を歓迎します。Issue・PR を出す前に、以下をご確認ください。

## 行動規範

本プロジェクトは [行動規範（CODE_OF_CONDUCT.md）](./CODE_OF_CONDUCT.md) を採用しています。参加するすべての方はこれに従ってください。

## はじめに

これは [Claude Code](https://claude.com/claude-code) のプラグインです。コンパイル対象のコードは無く、構成は次のとおりです。

- `agents/` — 専門エージェント定義（Markdown + YAML frontmatter）
- `skills/` — スキル定義（`SKILL.md`）
- `commands/` — フルサイクルコマンドとフェーズ定義
- `scripts/` — bash ヘルパーとそのテスト（`scripts/test/`）
- `vendor/` — 外部資産の vendored copy（**編集禁止**。後述）
- `.claude-plugin/plugin.json` — プラグインマニフェスト

開発上の詳細な規約は [CLAUDE.md](./CLAUDE.md) にまとまっています。

## Issue を出すとき

- バグ報告・機能要望は [Issue テンプレート](./.github/ISSUE_TEMPLATE/) を使ってください。
- **セキュリティ脆弱性は公開 Issue に投稿しないでください。** [SECURITY.md](./SECURITY.md) の private vulnerability reporting を使ってください。

## PR を出すとき

1. `main` から作業ブランチを切ってください（`feat/...`, `fix/...`, `docs/...` 等）。
2. 変更内容に対応する skill / agent / command / script を更新します。
3. スクリプトを変更した場合は、対応するテストを更新・実行してください。
   ```bash
   bash scripts/test/check-task-spawn.test.sh
   bash scripts/test/check-permissions.test.sh   # python3 が必要
   bash scripts/test/validate-fullcycle-schema.test.sh
   ```
4. `agents` / `skills` / `commands` を追加・削除した場合は `plugin.json` の該当配列を更新し、CLAUDE.md の「skills 整合ルール（三者一致）」を満たしてください。
5. PR テンプレートに沿って説明を記載してください。CI（schema 検証 / vendor 検証）が通ることを確認してください。

## バージョニング

[セマンティックバージョニング](https://semver.org/lang/ja/) に従います。判断基準は [CLAUDE.md](./CLAUDE.md) の「バージョニング」表を参照してください。`plugin.json` の `version` は **PR を merge する直前** に更新します（並行 PR では merge 時に連番を維持）。

## vendored 資産の扱い（重要）

`vendor/android-skills/` と `skills/swiftui-pro/` は外部リポジトリからの **vendored copy** です。**直接編集しないでください。** 変更が必要な場合は upstream に対して行い、同期スクリプトで取り込み直します。

```bash
./scripts/sync-android-skills.sh     # android/skills（SHA pin）
./scripts/sync-swiftui-pro.sh        # SwiftUI-Agent-Skill（SHA pin）
```

詳細・ライセンス・帰属は [NOTICE.md](./NOTICE.md) と [CLAUDE.md](./CLAUDE.md) を参照してください。

## ライセンス

本リポジトリへの貢献は、プロジェクトと同じ [MIT License](./LICENSE) の下で提供されることに同意したものとみなされます。
