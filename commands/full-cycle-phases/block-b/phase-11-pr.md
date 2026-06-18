# Phase 11: PR作成

> **実行層の制約（#52）**: `gh` / `git`（PR作成・コンフリクト解消の `git fetch/merge/push`）は
> **`Bash` を保有する層（orchestrator / `implementation-lead`）が直接実行**する。`feature-planner` /
> `spec-analyzer` / `app-reviewer` は `Bash` を持たないため、これらの agent に PR 作成やコンフリクト解消を
> 委譲できない。`Bash` を持つ agent に対しても PR 作成・コンフリクト解消は呼び出し元に集約する。
> 事前許可は Phase 1 で検証済み（`Bash(gh:*)` / `Bash(git:*)`）。

PR bodyテンプレートを読み込み、内容を埋めてPRを作成します：

1. `Read` ツールで `${CLAUDE_PLUGIN_ROOT}/templates/pr-body-template.md` を読み込む
2. テンプレートの各セクションを実装内容に基づいて記入する
3. 状態ファイル (`.full-cycle-state.json`) から `baseBranch` を確認する
4. `gh pr create` でPRを作成する

## 通常PR（baseBranch が main の場合）

```bash
gh pr create \
  --title "[type]: [タイトル]" \
  --body "<テンプレートに基づいて記入したPR body>"
```

## Stacked PR（baseBranch が main 以外の場合）

baseBranch が `main` 以外の場合、stacked PRとして作成する:

```bash
gh pr create \
  --title "[type]: [タイトル]" \
  --body "<テンプレートに基づいて記入したPR body>" \
  --base "${BASE_BRANCH}"
```

PR bodyには以下のセクションを追加する:

```markdown
### Stacked PR

- **Base branch**: `[baseBranch名]`
- ⚠️ このPRは base PR がマージされた後にマージしてください。
```

**注意**: UI変更がある場合、Phase 15でVRTスナップショットのbefore/after差分をPRコメントに添付します。

## PR作成成功・失敗時の状態記録

- **成功時**: 作成された PR 番号を状態ファイルの `prNumber`（state-schema.yaml 参照）に書き込む。
- **失敗時**（`gh pr create` がエラー / PR が作成されなかった場合）: 状態ファイルに `terminalState.kind=pr-failed`（phase: 11, reason, recordedAt）を記録し、ユーザーに報告して終了する（#29: 再開時に PR 未作成のまま無確認で先へ進まないようにする）。

## コンフリクトチェック＆解消

PR作成後、ベースブランチとのマージコンフリクトの有無をチェックし、コンフリクトがあれば解消します。

### コンフリクト検出

```bash
# PRのmergeability（マージ可能性）を確認
# 注意: PR作成直後は UNKNOWN を返す場合がある。UNKNOWN の場合は数秒待って再確認する。
gh pr view --json mergeable,mergeStateStatus
```

### コンフリクト解消（コンフリクトがある場合のみ）

mergeableが `CONFLICTING` の場合、`Skill` ツールで `pr-conflict-resolution` スキルを読み込み、ファイルタイプに応じた解消戦略を適用します：

```bash
# 1. PRのベースブランチを取得してマージ
BASE_BRANCH=$(gh pr view --json baseRefName -q '.baseRefName')
git fetch origin "${BASE_BRANCH}"
git merge "origin/${BASE_BRANCH}"

# 2. コンフリクトファイルを確認
git diff --name-only --diff-filter=U

# 3. ファイルタイプに応じた解消戦略を適用（pr-conflict-resolution スキル参照）
#    - ソースコード: 両方の変更意図を理解し統合
#    - ロックファイル: パッケージマネージャで再生成
#    - 自動生成ファイル: 生成元を解消してから再生成
#    - project.pbxproj: Tuist/XcodeGenがあれば再生成、なければ一方採用+再適用

# 4. コンフリクトマーカーが残っていないか確認
grep -rn "<<<<<<< " .

# 5. ビルド・テスト確認
# （プロジェクトに応じたビルド/テストコマンド）

# 6. マージコミット完了
git add <解消したファイル>
git merge --continue

# 7. リモートにプッシュ
git push
```

**コンフリクトがない場合**: このステップはスキップします。

**自動解消が困難な場合**: マージを中止 (`git merge --abort`) し、コンフリクトの状況をPRコメントに記録してユーザーに報告します。
