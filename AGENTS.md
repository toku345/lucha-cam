# Repository Guidelines

## プロジェクト構成

`LuchadorCam/` は SwiftUI アプリ本体です。カメラ制御は `CameraController.swift`、Vision の顔検出は `FaceDetector.swift`、座標変換は `FaceGeometry.swift` と `MaskGeometry.swift` に分かれています。`Tests/` には座標・変換処理の XCTest、`assets/` にはバンドルする透過 PNG を置きます。ビルド設定の正本は `project.yml` です。生成される `LuchadorCam.xcodeproj` と `.build/` は編集・コミットしないでください。

## ビルド・テスト・開発コマンド

macOS 26 以降、macOS 26 SDK を含む Xcode 26 以降（Swift 6）、XcodeGen 2.46.0 以降が必要です。リポジトリルートで実行します。

```sh
brew install xcodegen swiftlint editorconfig-checker # 初回のツール導入
editorconfig-checker
xcodegen generate
swiftlint lint --strict --no-cache
xcodebuild -project LuchadorCam.xcodeproj -scheme LuchadorCam \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build test
open .build/Build/Products/Debug/LuchadorCam.app
```

`xcodegen generate` はプロジェクト生成、`swiftlint` は静的検査、`xcodebuild ... test` はビルドと全ユニットテストを行います。ビルドのみの場合は末尾の `test` を `build` に変更します。アプリ起動時はカメラへのアクセスを許可してください。

## コーディング規約

整形規則は `.editorconfig`、Swift の静的検査は `.swiftlint.yml` を正本とします。EditorConfig 対応エディタを使用し、変更後は `editorconfig-checker` と SwiftLint を実行してください。両方とも CI で検査します。型は `UpperCamelCase`、関数・プロパティは `lowerCamelCase` を使います。UI と `CALayer` の更新は MainActor、キャプチャと Vision 処理は既存の専用 serial queue に保ちます。

## テスト方針

XCTest を使用し、ファイルは `*Tests.swift`、メソッドは `test...` と命名します。座標・変換処理の変更には、正常系と不正入力のテストを追加・更新してください。テストバンドルはアプリを起動せず、カバレッジ率の閾値は設けていません。映像処理や表示を変更した場合は、README の「実機確認」に従って追従・権限・終了時のカメラ停止も確認し、実施できなかった項目を報告します。

## コミットと Pull Request

コミット件名は履歴に合わせて `feat:`, `docs:`, `ci:`, `build:` などを付け、件名・本文を日本語で書きます。論理的な変更単位で分け、本文は diff だけでは分からない理由や制約がある場合に記載します。末尾に `Co-authored-by: Codex <model-id> <noreply@openai.com>` を正確に一つ含め、`<model-id>` は現在の正確なモデル識別子に置き換えます。不明な場合は推測せず、コミット前にユーザーへ確認してください。

このリポジトリでは Issue と PR のタイトル・本文を日本語で書きます。PR には変更目的、検証結果、未確認事項を記載します。関連 Issue があればリンクし、表示の変更は必要に応じてスクリーンショットで説明します。

## セキュリティと設定

カメラ映像や顔座標を保存しない設計を維持してください。権限・entitlements・バンドル設定は `project.yml` で変更します。マスク画像の差し替え時は `MaskGeometry.swift` の目のアンカーも確認してください。調整方法は README を参照してください。`assets/mask.png` はコード・ドキュメントの MIT ライセンス対象外で、別途の再利用ライセンスは設定されていません。
