---
name: pr-conflict-resolution
description: gitマージコンフリクトの体系的解消手法、PRコンフリクトの予防パターン、ファイルタイプ別の解消戦略、モバイル開発固有のコンフリクト対応を含むPRコンフリクト解消の専門知識。コンフリクト解消、マージ戦略の選択、チーム開発でのブランチ管理時に使用します。
model: opus
allowed-tools: Read, Glob, Grep, Bash, Edit, WebSearch
user-invocable: false
---

# PR Conflict Resolution

## Evidence-First Conflict Resolution

**Core Belief**: "コンフリクトは開発プロセスの自然な一部であり、体系的なアプローチと予防策により効率的に管理できる"

### Standards Compliance
- Git公式ドキュメント (merge strategies, conflict resolution)
- Atlassian Git Tutorials (branching strategies)
- GitHub Flow / GitLab Flow のベストプラクティス
- Trunk Based Development の原則

### Proven Patterns
- 小さなPR・頻繁なマージによるコンフリクト予防
- 定期的なbase branchのrebase/merge
- ファイルタイプに応じた解消戦略の使い分け
- 自動化ツールによるコンフリクト検出と解消補助

## Discussion Characteristics

### Discussion Stance
- **Systematic**: コンフリクトの原因を特定し、体系的に解消する
- **Preventive**: コンフリクト発生を最小化するプラクティスを重視
- **Context-Aware**: プロジェクトのブランチ戦略とチーム構成に応じた判断

### Key Discussion Points
- merge vs rebase の使い分け
- コンフリクト解消の自動化と手動対応の境界
- チーム規模に応じたブランチ戦略
- モバイル開発特有のコンフリクトパターン

### Evidence Sources
- Git公式ドキュメント (git-merge, git-rebase)
- Atlassian "Comparing Workflows"
- Google Engineering Practices (Large-Scale Changes)

### Strengths
- コンフリクトの根本原因を特定し再発を防止
- ファイルタイプに応じた最適な解消手法を提供
- チーム開発における予防的プラクティスを推進

### Potential Biases
- rebase推奨に偏りがち（チームの慣習も考慮が必要）
- 完全な自動化を目指しすぎるリスク（手動判断が必要な場面もある）
- 小さなPRの推奨がチームのレビュー負荷を増やす可能性

---

## コンフリクトの種類と原因

### 1. テキストコンフリクト（Textual Conflict）

同じファイルの同じ行を異なるブランチで変更した場合に発生する。

```
<<<<<<< HEAD
const MAX_RETRIES = 5;
=======
const MAX_RETRIES = 10;
>>>>>>> feature/increase-retries
```

**原因**: 同一箇所の並行編集
**解消**: どちらの値が正しいか、変更意図を確認して選択

### 2. セマンティックコンフリクト（Semantic Conflict）

テキスト上はコンフリクトしないが、論理的に矛盾する変更。

```
// Branch A: 関数名を変更
function calculateTotal(items: Item[]): number { ... }

// Branch B: 旧関数名で呼び出しを追加
const result = computeTotal(cartItems);
// → マージ後にコンパイルエラー
```

**原因**: 依存関係のある異なる箇所の変更
**検出**: マージ後のビルド・テスト実行で検出
**予防**: CI/CDでのマージ後自動テスト

### 3. 構造的コンフリクト（Structural Conflict）

ファイルの移動・リネーム・削除が絡むコンフリクト。

```bash
# Branch A: ファイルをリネーム
git mv src/utils.ts src/helpers.ts

# Branch B: 同じファイルを編集
# → マージ時にgitが追跡を見失う可能性
```

**原因**: ファイル構造の並行変更
**解消**: `git log --follow` でファイル履歴を確認

### 4. 依存関係コンフリクト（Dependency Conflict）

パッケージ管理ファイルやロックファイルのコンフリクト。

```
# package-lock.json, Podfile.lock, Gradle dependency resolution
# → 手動解消ではなく再生成が基本
```

**原因**: 異なるブランチでの依存関係変更
**解消**: ロックファイルは再生成、設定ファイルは意図を確認して統合

---

## git merge vs rebase の使い分け

### merge を選ぶ場合

```bash
git checkout feature/my-feature
git merge main
```

**適するケース**:
- 共有ブランチ（他の開発者もpushしている）
- マージ履歴を残したい場合
- コンフリクトが多く、段階的に解消したい場合
- リリースブランチへの統合

**メリット**:
- 履歴が改変されない（安全）
- コンフリクト解消が1回で済む
- 共有ブランチでも問題なく使える

**デメリット**:
- マージコミットが増えて履歴が複雑になる
- bisectが難しくなる場合がある

### rebase を選ぶ場合

```bash
git checkout feature/my-feature
git rebase main
```

**適するケース**:
- 個人の作業ブランチ（まだpushしていない or force push可能）
- クリーンな線形履歴を維持したい場合
- 小さなコミットを整理したい場合

**メリット**:
- 線形な履歴で読みやすい
- bisectが容易
- 不要なマージコミットがない

**デメリット**:
- 履歴を書き換えるため、共有ブランチでは危険
- コンフリクトがコミットごとに発生する可能性
- 解消を間違えるとやり直しが困難

### 判断フローチャート

```
そのブランチは他の人もpushしている？
├── Yes → merge を使う
└── No → 履歴をきれいにしたい？
    ├── Yes → rebase を使う
    └── No → merge でもOK
```

---

## コンフリクト解消の体系的手順

### Step 1: 状況把握

```bash
# コンフリクトの全体像を確認
git status

# コンフリクトファイルの一覧
git diff --name-only --diff-filter=U

# コンフリクトの詳細を確認
git diff
```

### Step 2: コンフリクトの原因調査

```bash
# 各ブランチでの変更内容を確認
git log --oneline main..HEAD -- <conflicted-file>
git log --oneline HEAD..main -- <conflicted-file>

# 誰がどの行を変更したか確認
git log -p --merge -- <conflicted-file>

# マージベースを確認
git merge-base HEAD main
```

### Step 3: コンフリクト解消

```bash
# エディタでコンフリクトマーカーを編集
# <<<<<<< HEAD
# (現在のブランチの変更)
# =======
# (マージ対象ブランチの変更)
# >>>>>>> branch-name

# 特定のブランチの変更を採用
git checkout --ours <file>    # 現在のブランチを採用
git checkout --theirs <file>  # マージ対象を採用

# マージツールを使用
git mergetool
```

### Step 4: 解消の検証

```bash
# コンフリクトマーカーが残っていないか確認
grep -rn "<<<<<<< " .
grep -rn "=======" .
grep -rn ">>>>>>> " .

# ビルドが通るか確認
# (プロジェクトに応じたビルドコマンド)

# テストが通るか確認
# (プロジェクトに応じたテストコマンド)
```

### Step 5: コミット

```bash
# 解消したファイルをステージング
git add <resolved-files>

# マージコミットを完了（mergeの場合）
git merge --continue

# rebaseの場合
git rebase --continue
```

---

## ファイルタイプ別の解消戦略

### ソースコード（.swift, .kt, .ts, .py等）

**方針**: 両方の変更意図を理解し、論理的に統合する

```
1. 各ブランチの変更意図をコミットメッセージ・PRで確認
2. 両方の変更を統合できるか検討
3. 統合できない場合、優先度の高い変更を選択
4. 統合後にビルド・テストで検証
```

**注意点**:
- import文のコンフリクトは両方追加が基本
- 関数追加のコンフリクトは両方残して順序を調整
- ロジック変更のコンフリクトは慎重に統合

### 設定ファイル（.json, .yaml, .toml, .plist等）

**方針**: 構造を理解して手動マージ

```
1. 各ブランチで追加/変更されたキーを特定
2. キーの重複がなければ両方追加
3. 同一キーの変更は意図を確認して選択
4. JSON/YAMLのバリデーションで構文を検証
```

### ロックファイル（package-lock.json, Podfile.lock, yarn.lock等）

**方針**: 手動編集せず再生成する

```bash
# Node.js
git checkout --theirs package-lock.json  # または --ours
npm install

# CocoaPods
git checkout --theirs Podfile.lock  # または --ours
pod install

# Yarn
git checkout --theirs yarn.lock
yarn install

# Gradle (dependency lock)
./gradlew dependencies --write-locks
```

**重要**: ロックファイルは手動編集しない。必ずパッケージマネージャで再生成する。

### 自動生成ファイル

**方針**: 生成元を解消してから再生成

```
1. 生成元ファイル（スキーマ、設定等）のコンフリクトを先に解消
2. 自動生成コマンドを実行して再生成
3. 生成結果を確認してステージング
```

---

## モバイル開発固有のコンフリクト

### Xcode project.pbxproj

最もコンフリクトが発生しやすいファイルの一つ。

**特徴**:
- UUIDベースの参照で人間には読みにくい
- ファイル追加/削除で頻繁にコンフリクト
- 手動解消が困難

**解消戦略**:

```bash
# 方法1: 一方を採用してファイル参照を再追加
git checkout --ours ProjectName.xcodeproj/project.pbxproj
# Xcodeでファイル参照を手動追加

# 方法2: マージツールを使用
git mergetool -t opendiff  # FileMerge (macOS)

# 方法3: Tuist/XcodeGenを使用している場合は再生成
tuist generate
# または
xcodegen generate
```

**予防策**:
- **Tuist / XcodeGen** を使ってproject.pbxprojを自動生成する
- ファイル追加は別コミットにする
- 同時に新ファイルを追加する作業を避ける

### Gradle設定ファイル（build.gradle, build.gradle.kts）

**コンフリクトパターン**:
```kotlin
// Branch A: ライブラリバージョン更新
implementation("com.google.firebase:firebase-bom:32.7.0")

// Branch B: 別のライブラリ追加
implementation("com.google.firebase:firebase-bom:32.6.0")
implementation("com.squareup.retrofit2:retrofit:2.9.0")
```

**解消戦略**:
```
1. バージョンの競合 → 新しい方を採用（互換性確認）
2. 依存関係の追加 → 両方追加
3. ビルド設定の変更 → 意図を確認して統合
4. 解消後に ./gradlew build で検証
```

**予防策**:
- Version Catalogの活用（`libs.versions.toml`）
- 依存関係のバージョンを一箇所で管理

### Info.plist / AndroidManifest.xml

**コンフリクトパターン**:
```xml
<!-- Branch A: パーミッション追加 -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- Branch B: 別のパーミッション追加 -->
<uses-permission android:name="android.permission.LOCATION" />
```

**解消戦略**:
```
1. 権限/設定の追加 → 両方追加（重複に注意）
2. バージョン番号の変更 → 大きい方を採用
3. 機能フラグの変更 → 意図を確認
4. XMLバリデーションで構文確認
```

### ストーリーボード / XIBファイル

**特徴**:
- XMLベースだが自動生成部分が多い
- IDの衝突が起きやすい
- 手動編集が非常に困難

**解消戦略**:
```
1. 可能な限り一方を採用して、もう一方の変更を手動再適用
2. Interface Builderで開いて確認
3. できればコードベースUI（SwiftUI/Compose）への移行を検討
```

### リソースファイル（strings.xml, Localizable.strings等）

**コンフリクトパターン**:
```xml
<!-- Branch A -->
<string name="welcome_message">Welcome!</string>
<string name="error_network">Network error</string>

<!-- Branch B -->
<string name="welcome_message">Hello!</string>
<string name="error_timeout">Request timed out</string>
```

**解消戦略**:
```
1. 新規追加キー → 両方追加
2. 同一キーの値変更 → 仕様を確認して正しい方を選択
3. キーのリネーム → 参照箇所も含めて統合
4. ソート順がある場合はソート順を維持
```

---

## PRコンフリクトの予防パターン

### 1. 小さなPRを心がける

```
目安:
- 変更行数: 200-400行以下
- 変更ファイル数: 10ファイル以下
- レビュー時間: 30分以内で完了できる規模

大きな機能は Feature Flag で分割:
- PR 1: データモデルの追加
- PR 2: API層の実装
- PR 3: UI層の実装
- PR 4: Feature Flag の有効化
```

### 2. 定期的なbase branchの取り込み

```bash
# 毎日の作業開始時にbase branchを取り込む
git fetch origin
git rebase origin/main  # または git merge origin/main

# 長期ブランチの場合は少なくとも週2-3回
```

### 3. ブランチ戦略の最適化

**GitHub Flow（推奨: 小〜中規模チーム）**:
```
main ← feature branches
- mainは常にデプロイ可能
- featureブランチは短命（1-3日）
- PR経由でmainにマージ
```

**Trunk Based Development（推奨: 大規模チーム）**:
```
main ← short-lived feature branches (< 1日)
- Feature Flagで未完成機能を隔離
- 頻繁な統合でコンフリクトを最小化
```

### 4. ファイルオーナーシップの明確化

```
CODEOWNERS ファイルで担当を明確化:
# .github/CODEOWNERS
/ios/     @ios-team
/android/ @android-team
/shared/  @platform-team

→ 同一ファイルを複数チームが同時編集する状況を減らす
```

### 5. コミュニケーション

```
- 大きな変更を始める前にチームに共有
- 同じファイルを編集する予定がある場合は調整
- リファクタリングは専用PRで先にマージ
```

---

## gitコマンドリファレンス

### コンフリクト解消の基本コマンド

```bash
# マージを開始
git merge <branch>

# コンフリクト状態の確認
git status
git diff --name-only --diff-filter=U

# 特定ブランチの変更を採用
git checkout --ours <file>     # 現在のブランチ
git checkout --theirs <file>   # マージ対象ブランチ

# マージツールで解消
git mergetool

# 解消完了をマーク
git add <file>

# マージを完了
git merge --continue

# マージを中止（やり直す場合）
git merge --abort
```

### rebase時のコンフリクト解消

```bash
# rebaseを開始
git rebase <branch>

# コンフリクト解消後に続行
git rebase --continue

# 現在のコミットをスキップ
git rebase --skip

# rebaseを中止
git rebase --abort
```

### 調査・分析コマンド

```bash
# マージベースを確認
git merge-base HEAD <branch>

# ブランチ間の差分ファイル一覧
git diff --name-only <branch>...HEAD

# 特定ファイルの変更履歴
git log --oneline -p -- <file>

# リネームを追跡した履歴
git log --follow -- <file>

# コンフリクトが発生するか事前確認（ドライラン）
git merge --no-commit --no-ff <branch>
git merge --abort  # 確認後に中止
```

### 便利なエイリアス

```bash
# コンフリクトファイルの一覧
git config --global alias.conflicts "diff --name-only --diff-filter=U"

# コンフリクトマーカーの検索
git config --global alias.conflict-markers "!grep -rn '<<<<<<< ' ."
```

---

## Anti-Patterns（よくある失敗パターン）

### 1. 盲目的にours/theirsを選択

```bash
# ❌ 中身を確認せずに一方を採用
git checkout --ours .
git add .
git commit -m "resolve conflicts"
```

**問題**: 相手の変更が完全に失われる
**正解**: 各ファイルのコンフリクトを確認し、必要な変更を統合する

### 2. コンフリクトマーカーの残存

```typescript
// ❌ マーカーが残ったままコミット
<<<<<<< HEAD
const timeout = 5000;
=======
const timeout = 10000;
>>>>>>> feature/update-timeout
```

**予防**: コミット前に `grep -rn "<<<<<<< " .` で確認

### 3. ロックファイルの手動編集

```json
// ❌ package-lock.jsonを手動でマージ
{
  "dependencies": {
    "lodash": {
      "version": "4.17.21",
      // 手動で編集した不整合な内容
    }
  }
}
```

**正解**: 一方を採用してパッケージマネージャで再生成

### 4. 長期間のブランチ放置

```
❌ 2週間以上mainからの乖離を放置
→ コンフリクトが大量に蓄積して解消困難に

✅ 毎日mainを取り込む
→ コンフリクトが小さいうちに解消
```

### 5. rebase後のforce pushの不注意

```bash
# ❌ 共有ブランチでforce push
git push --force origin shared-branch
# → 他の開発者の作業が消える

# ✅ force pushは個人ブランチのみ
git push --force-with-lease origin my-feature
# --force-with-lease はリモートの変更を確認してからpush
```

### 6. テストなしでのマージ完了 / 無差別な `git add`

```bash
# ❌ コンフリクト解消後にすぐコミット（しかも git add . で無差別ステージ）
git add .
git merge --continue

# ✅ 解消したファイルのみを個別 add し、ビルドとテストを実行してからコミット
git add $(git diff --name-only --diff-filter=U)  # コンフリクト解消済みファイルのみ
# ビルド・テスト実行
git merge --continue
```

**`git add .` / `git add -A` が危険な理由**: コンフリクト解消とは無関係な
**未追跡ファイルを無差別にステージ**してしまう。特にフルサイクル開発の状態ファイル
（`.full-cycle-state.json` / `.parallel-full-cycle-state.json`）はユーザーの worktree に
生成されるが利用側リポジトリの `.gitignore` には載っていないため、`git add .` で混入し、
直後の `git push` でリモートへ公開される。未 ignore の秘匿ファイル（`.env` 等）も同様に
巻き込まれ、情報漏洩・リポジトリ汚染事故につながる。

> **git add の対象（#64）**: コンフリクト解消では `git diff --name-only --diff-filter=U`
> で列挙したファイルのみを個別 add する。除外対象（状態ファイル・`.DS_Store` 等）は
> `commands/full-cycle-phases/block-b/phase-10-commit.md` の「git add 除外対象」に揃える。

### 7. project.pbxproj の手動編集ミス

```
❌ UUID参照を手動で編集して不整合に
→ Xcodeがプロジェクトを開けなくなる

✅ 一方を採用して、もう一方の変更をXcodeから再適用
```

---

## MECE分析フレームワーク

### コンフリクト解消の判断マトリクス

| コンフリクトタイプ | 自動解消可能性 | 推奨アプローチ | リスクレベル |
|---|---|---|---|
| import文の追加 | 高 | 両方追加 | 低 |
| 関数追加（別々の関数） | 高 | 両方追加 | 低 |
| 同一関数のロジック変更 | 低 | 手動統合 | 高 |
| 設定値の変更 | 低 | 意図確認後に選択 | 中 |
| ロックファイル | 高 | 再生成 | 低 |
| project.pbxproj | 低 | ツール使用 or 再生成 | 高 |
| 自動生成ファイル | 高 | 再生成 | 低 |
| リソースファイル | 中 | キー単位で統合 | 中 |

### 解消優先度

1. **ビルドブロッカー**: ビルドを通せないコンフリクト → 最優先
2. **テスト失敗**: テストが通らないコンフリクト → 高優先
3. **ロジック統合**: 両方の変更を正しく統合 → 中優先
4. **スタイル・フォーマット**: コードスタイルの差異 → 低優先
