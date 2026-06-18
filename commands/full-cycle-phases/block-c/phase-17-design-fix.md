# Phase 17: Design修正対応 → 追加コミット

Design Reviewで指摘された問題を修正します。**UI修正もパッチではなく、VRT（Visual Regression Test）先行更新の規律で行う**こと。

## 修正方針の決定（指摘ごとに分類）

| カテゴリ | 例 | 修正フロー |
|---------|----|-----------|
| **A: ロジックを伴うUI修正** | 表示条件の変更、状態管理、エラーハンドリング表示 | **TDD必須**（Phase 14 のカテゴリA と同じ流れ） |
| **B: 純粋な見た目変更** | 色・余白・フォント・レイアウト調整 | **VRT先行更新**（下記） |
| **C: 文言・アイコン差し替え** | テキスト変更、アイコン置換 | VRT先行更新（B と同じ） |

## カテゴリB/C: VRT先行更新フロー

パッチ修正ではなく、以下の順序で実施する:

1. **Red相当**: 期待される新しい見た目をスナップショット名で意図表明
   - 既存のVRTテストを Read し、修正対象のスナップショットを特定
   - スナップショット名やテストケース名が修正意図を反映していなければ更新
2. **修正**: 該当UIコードを Edit
3. **Green相当**: VRT を実行し、新しいスナップショットで通ることを確認
   - iOS: `swift test --filter [VRTテストクラス]` でスナップショット記録
   - Android: `./gradlew recordPaparazzi[Variant]` でスナップショット記録
4. **before/after を必ず確認**: スナップショット差分を目視レビュー（意図しない変更がないか）

UI修正は「既存テストが通った＝OK」ではなく、「**新スナップショットが意図通り＝OK**」が判定基準。

## カテゴリA: ロジックを伴うUI修正

Phase 14 のカテゴリA と同じく `tdd-test-writer` を使い、Red→Green→Refactor で修正する。
UIロジックのテスト（ViewModel、状態遷移、Reducer等）を書いてから実装を直す。

## 共通: 修正後のコミット

1. 指摘事項を修正（カテゴリ別フローに従う）
2. 修正内容をコミット

```bash
git add [修正ファイル]
git commit -m "fix: design review指摘対応

- [修正内容1]
- [修正内容2]

Refs: #[issue番号]"
```

3. PRを更新（自動的にpush）

```bash
git push
```

4. ビルド・テスト確認

```bash
# プロジェクトに応じたビルド確認
# iOS: xcodebuild build -scheme [Scheme] -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
# Android: ./gradlew assembleDebug

# テスト実行（既存テストの回帰確認）
# iOS: xcodebuild test -scheme [Scheme] -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
# Android: ./gradlew testDebugUnitTest
```

5. UI変更があった場合の VRT 再実行判断

カテゴリB/C で VRT を先行更新済みであれば、このステップは確認のみで OK。
カテゴリA でUIに副次的な変更が出た場合は、Phase 16 に戻る前に Phase 15（VRT）を再実行してスナップショットを更新する。

判定基準:
- `.swift` / `.kt` のUI関連ファイルに変更がある → VRT 再実行（カテゴリB/Cは更新済みのはず）
- リソースファイル（色定義、画像アセット）のみの変更 → VRT 再実行
- ロジックのみの変更（ViewModel 等） → VRT 再実行不要（ただしViewModelテストはカテゴリAで追加済み）

## 遷移先

修正・プッシュ完了後 → **Phase 16 へ**（Design Review 再確認）

Phase 16 で 🟢承認 が出れば → Phase 18 へ進む。

**ループ上限**: Phase 16 ↔ 17 のループ上限は `_schema/phase-flow.yaml` の `loops.designReview` を正本とする（数値をハードコードしない）。上限到達時はユーザーに報告して終了（Phase 16 側で `designReviewLoopCount` を管理し `terminalState` を記録）。
