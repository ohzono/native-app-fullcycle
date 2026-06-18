# Phase 15: VRTスナップショットテスト実行

## 目的

デザインレビュー（Phase 16）に必要なスナップショット画像を生成・更新します。
**UI変更を含む実装の場合、このフェーズは必須です。**

## 並行実行モード（Phase 12と同時）

`currentPhase = 12` 開始時は、`code-reviewer` と並行して
`vrt-engineer` に `SendMessage` します。

```yaml
SendMessage:
  to: vrt-engineer
  message: |
    Issue #{issue番号} のVRTスナップショット生成を実行してください。
    手順は本フェーズ定義（phase-15-vrt.md）の 1〜5 に従ってください。
```

- VRT 実行中でも、Code Review結果が揃えば Phase 13/14 を先行してよい
- Phase 16 開始前には、必ずVRT完了と `snapshots` 更新を確認する
- Team未使用時は本フェーズの手順をメインプロセスで直接実行する

## 処理内容

### 1. UI変更の有無を判定

```bash
# 状態ファイルからベースブランチを取得（mainハードコードを避ける）
BASE_BRANCH=$(jq -r '.baseBranch' .full-cycle-state.json)

# git diff で UI関連ファイルを抽出
git diff "$BASE_BRANCH" --name-only | grep -E '\.(swift|kt)$' | head -20

# SwiftUI / Compose ファイルかを確認
# - iOS: *View.swift, *Screen.swift, UI関連コード
# - Android: *Screen.kt, *Composable.kt, UI関連コード
```

**判定結果**:
- UI変更あり → 続行
- UI変更なし → Phase 16へスキップ（スキップ理由を記録）

### 1.5 スナップショットバリエーション指針

以下のバリエーションを網羅すること:

| カテゴリ | バリエーション |
|---------|--------------|
| テーマ | ライト / ダーク |
| デバイス | 小画面 (iPhone SE / Pixel 4a) / 標準 (iPhone 15 Pro / Pixel 6) |
| アクセシビリティ | Dynamic Type XL / フォントスケール 1.5f |
| UI状態 | Loading / Success（デフォルト） / Error / Empty |

UI状態が該当しないコンポーネント（静的な設定画面等）はデフォルト表示のみでよい。

### 2. プラットフォーム判定

```bash
# プロジェクト構造からプラットフォームを判定
if ls *.xcodeproj &>/dev/null || ls Package.swift &>/dev/null; then
    echo "iOS"
elif ls build.gradle.kts &>/dev/null || ls settings.gradle.kts &>/dev/null; then
    echo "Android"
fi
```

### 3. VRTテスト生成・実行

#### iOS の場合

```
# 1. 既存VRTテストの確認
Glob: **/__Snapshots__/**/*.png

# 2. テストがない場合 → vrt-engineer エージェントで VRTテスト生成
Task:
  description: iOS VRTスナップショットテストを生成
  subagent_type: mobiledev-fullcycle:vrt-engineer
  prompt: |
    以下のSwiftUIファイルに対してスナップショットテストを生成してください。
    対象ファイル: {変更されたSwiftUIファイルパス}
    
    swift-snapshot-testing を使用し、以下のバリエーションを含めてください:
    - デフォルト表示
    - ダークモード
    - Dynamic Type（アクセシビリティサイズ）
    - 複数デバイス（iPhone SE, iPhone 15 Pro）
    - UI状態バリエーション（Loading, Error, Empty, Success）

# 3. テストがある場合 → スナップショット更新
Bash: xcodebuild test \
  -scheme [Scheme] \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:[TestTarget]/[SnapshotTestClass]
```

#### Android の場合

```
# 1. 既存VRTテストの確認
Glob: **/snapshots/**/*.png

# 2. テストがない場合 → vrt-engineer エージェントで VRTテスト生成
Task:
  description: Android VRTスナップショットテストを生成
  subagent_type: mobiledev-fullcycle:vrt-engineer
  prompt: |
    以下のComposeファイルに対してスナップショットテストを生成してください。
    対象ファイル: {変更されたComposeファイルパス}
    
    Compose Preview Screenshot Testing を使用し、以下のバリエーションを含めてください:
    - デフォルト表示
    - ダークテーマ
    - フォントスケール（1.5f）
    - 複数画面サイズ（Phone, Tablet）
    - UI状態バリエーション（Loading, Error, Empty, Success）

# 3. テストがある場合 → スナップショット記録
Bash: ./gradlew updateDebugScreenshotTest
```

### 4. スナップショットパスの記録と状態ファイル更新

生成されたスナップショットのパスを**状態ファイルに保存**し、Phase 16に引き継ぎます。

```bash
# 状態ファイルの snapshots フィールドを更新
# Write ツールで .full-cycle-state.json を更新:
# "snapshots": [
#   "Tests/__Snapshots__/HomeViewTests/testHomeView.1.png",
#   "Tests/__Snapshots__/HomeViewTests/testHomeView_dark.1.png"
# ]
# "currentPhase": 16
```

**ユーザーへの出力**:
```markdown
## VRTスナップショット生成結果

### 生成されたスナップショット
| 画面 | デバイス | テーマ | パス |
|------|----------|--------|------|
| [画面名] | [デバイス] | [テーマ] | [パス] |

→ Phase 16 (design-review) でこれらのスナップショットを視覚確認します
```

### 5. Phase 15b: PRにスナップショット前後差分を添付

VRTスナップショット生成後、変更されたスナップショットの**before/after比較**をPRコメントに投稿します。

- Phase 14（Fix）未完了ならコメント投稿は遅らせてよい
- Phase 14でUI変更が入った場合は、再実行後の最新スナップショットで投稿する
- **前提**: スナップショットはステップ4でコミット済みであること。未コミットの場合はコミットしてからステップ5.2に進む

#### 5.1 変更スナップショットの特定

```bash
# ベースブランチとの差分でスナップショットファイルを抽出
BASE_BRANCH=$(jq -r '.baseBranch' .full-cycle-state.json)
git diff "$BASE_BRANCH" --name-only -- '*.png' | grep -E '(__Snapshots__|snapshots)/'
```

#### 5.2 before/after比較テーブルの生成

変更されたスナップショットごとに、以下のいずれかのパターンで比較を生成：

**新規追加の場合（beforeなし）:**
```markdown
| 画面 | After |
|------|-------|
| [画面名] | ![after](スナップショットパス) |
```

**変更の場合（before/afterあり）:**

push済みであることを前提に、GitHub raw URLで比較テーブルを構築する。

```bash
# プッシュ済みか確認（未プッシュの場合は先にpushする）
if ! git status -sb | head -1 | grep -q '\.\.\.' ; then
  git push -u origin $(git branch --show-current)
elif git status -sb | head -1 | grep -q 'ahead' ; then
  git push
fi

# リポジトリ情報を取得
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
BRANCH=$(git branch --show-current)

# before: ベースブランチのraw URL
BASE_BRANCH=$(jq -r '.baseBranch' .full-cycle-state.json)
# https://raw.githubusercontent.com/{REPO}/{BASE_BRANCH}/{スナップショットパス}
# after: 現在のブランチのraw URL
# https://raw.githubusercontent.com/{REPO}/{BRANCH}/{スナップショットパス}
```

```markdown
| 画面 | Before | After |
|------|--------|-------|
| [画面名] | ![before](https://raw.githubusercontent.com/{REPO}/{BASE_BRANCH}/{パス}) | ![after](https://raw.githubusercontent.com/{REPO}/{BRANCH}/{パス}) |
```

#### 5.3 PRコメントへの投稿

```bash
gh pr comment [PR番号] --body "<details>
<summary>🤖 📸 VRT スナップショット差分 — 新規 [N] / 変更 [N] / 削除 [N]</summary>

## 📸 VRT スナップショット差分

### 変更されたスナップショット

| 画面 | Before | After |
|------|--------|-------|
| [画面名] | [before画像 or N/A（新規）] | [after画像] |

### サマリー
- 新規追加: [N]件
- 変更: [N]件
- 削除: [N]件

</details>
"
```

#### 5.4 状態ファイルの更新

```bash
# 状態ファイルの snapshotComment フィールドを更新
# Write ツールで .full-cycle-state.json を更新:
# "snapshotComment": true
```

## UI変更がない場合のスキップ

UI変更がない場合、Phase 15 と Phase 16 をスキップして Phase 18 に直接進む。
スキップ理由を状態ファイルに記録する:

```bash
# 状態ファイル更新:
# "snapshots": []
# "currentPhase": 18
# "skippedPhases": [15, 16, 17]
```

## Phase 14後の再実行条件

Phase 14 でUI変更を含む修正を行った場合、Phase 16 の前に Phase 15 を再実行すること。
