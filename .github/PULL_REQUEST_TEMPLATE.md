<!-- このテンプレートは本リポジトリ（プラグイン）への貢献用です。
     プラグインがユーザーのリポジトリに自動生成する PR 本文は templates/pr-body-template.md です（別物）。 -->

## 概要

<!-- 何を・なぜ変更したか。関連 Issue があれば `Closes #123` で紐付け。 -->

## 変更の種類

- [ ] バグ修正
- [ ] 新機能（skill / agent / command の追加）
- [ ] 既存の skill / agent / command の挙動変更
- [ ] ドキュメント / README / CLAUDE.md
- [ ] vendored 資産の同期（sync スクリプト経由）
- [ ] その他

## チェックリスト

- [ ] `main` から作業ブランチを切った
- [ ] skill / agent / command を増減した場合、`plugin.json` を更新し「三者一致ルール」（CLAUDE.md）を満たした
- [ ] スクリプトを変更した場合、`scripts/test/` のテストを更新・実行した
- [ ] `version` の bump 要否を確認した（基準は CLAUDE.md。bump は merge 直前）
- [ ] vendored 資産（`vendor/`, `skills/swiftui-pro/`）を直接編集していない
- [ ] CI（schema 検証 / vendor 検証）が通ることを確認した

## 補足

<!-- レビュアーに伝えたいこと、動作確認の手順、スクリーンショット等 -->
