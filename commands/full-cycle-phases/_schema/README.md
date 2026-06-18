# フルサイクル状態機械の正本（source of truth）

このディレクトリはフルサイクル開発の状態定義の**唯一の正本**です。

- `state-schema.yaml` — 状態ファイルの全フィールド・型・正準名・デフォルト
- `phase-flow.yaml` — フェーズ遷移・ループ上限・終局条件・各フェーズの読み書き契約

## 参照のしかた

フェーズファイル（`../block-*/phase-*.md`）・コマンド（`../../*.md`）・
`skills/status`・`skills/cleanup` は、状態フィールド名・ループ上限・終局条件を
**ここから参照**し、自分で再定義しないこと。

参照例:
> 状態スキーマは `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/_schema/state-schema.yaml` を正本とする。
> ループ上限は `phase-flow.yaml` の `loops.codeReview` を参照。

## 検証

`scripts/validate-fullcycle-schema.sh` が CI（`.github/workflows/validate-schema.yml`）で
正本とドキュメント・読み手の整合を検証する。drift（数値のハードコード・インライン状態JSON）
を混入させると CI が落ちる。
