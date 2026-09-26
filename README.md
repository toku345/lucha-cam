# lucha-cam

Macのカメラ映像に、顔の両目へ位置・大きさ・回転を合わせた透過PNGを重ねる実験アプリ。
Swift / SwiftUI / AVFoundation / Vision / Core Animationを使用する。
アプリ名・Xcodeプロジェクト名・scheme名は`LuchadorCam`。

## 必要環境

- macOS 26以降。実機確認環境はmacOS 27.0。
- macOS 26 SDKを含むXcode 26以降（Swift 6）。開発環境はXcode 27.0。
- XcodeGen 2.46.0以降
- 利用可能なカメラとカメラへのアクセス許可

## 生成・ビルド・起動

リポジトリルートで実行する。

```sh
xcodegen generate
xcodebuild \
  -project LuchadorCam.xcodeproj \
  -scheme LuchadorCam \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath .build \
  build
open .build/Build/Products/Debug/LuchadorCam.app
```

Xcodeで実行する場合は生成されたプロジェクトを開き、LuchadorCam scheme / My MacでRunする。
設定変更は`project.yml`へ記述して再生成する。生成プロジェクトと`.build`はGit管理しない。
署名はローカル実行用のad-hoc署名。再ビルド後にカメラ権限を再要求されることがある。

初回のカメラ要求を許可するとシステム既定のカメラを開始する。
拒否時は説明を表示する。システム設定 → プライバシーとセキュリティ → カメラで
LuchadorCamを許可し、アプリを起動し直す。
赤いボタンでウィンドウを閉じるとcapture sessionが停止し、アプリも終了する。
再び使う場合は上記の`open`コマンドを実行する。

## 動作と座標系

- Sessionの構成・start・stopは専用serial queue、UIとCALayerはMainActorで扱う。
- VideoDataOutputは`alwaysDiscardsLateVideoFrames = true`。専用serial delegate queueで
  Visionの顔ランドマーク検出を同期実行し、開始間隔を100ms以上に制限する。
- 最大の顔1件を使い、目の輪郭点の平均を代表点とする。顔や片目が取れなければマスクを隠す。
- 出力接続を回転0°・非反転に設定し、フレームの接続状態とorientation attachmentも確認する。
  この条件でVisionへ`.up`を渡し、異なる入力は説明を表示して検出しない。
- 顔内のランドマークを画像全体の正規化座標に変換し、左下原点から左上原点へ合わせる。
  PreviewLayerの既存変換APIで`.resizeAspectFill`のcrop・回転・mirrorを扱う。
  手動のX反転やcrop倍率計算はしない。ホストNSViewは`isFlipped = true`。
- PNGはBundleからImageIOで一度デコードし、CALayerで再利用する。
  両目の距離比・角度差・中点からaffine transformを計算する。暗黙アニメーションは無効。
- 緑の顔枠、水色のVision leftEye、オレンジのrightEyeは確認用に表示する。

画像や顔座標は保存しない。起動・入力の向き・初回検出・停止・エラーをログに出す。
Xcodeコンソール、または終了後に以下で起動してログを確認できる。

```sh
.build/Build/Products/Debug/LuchadorCam.app/Contents/MacOS/LuchadorCam
```

## マスク画像と調整

`assets/mask.png`は、このプロジェクト用に使用者がChatGPTで新たに生成した
青緑・オレンジのサンプル画像。画像は1211×1299の透過PNG。

`LuchadorCam/MaskGeometry.swift`に画像の左上原点の正規化アンカーをまとめている。

- `leftEyeAnchor = (0.290, 0.428)`、約(351, 556)ピクセル
- `rightEyeAnchor = (0.708, 0.428)`、約(857, 556)ピクセル

PNGの目穴の中心を目安にした値。画像内の目の中心が(x, y)、寸法が(W, H)なら
アンカーを(x / W, y / H)にする。透明余白も寸法に含む。
値の変更や画像の差し替え後は再ビルドして実機確認する。

- 両アンカーを下げるとマスクは画像の上方向へ、右へ動かすと画像の左方向へ移動する。
- 中点を固定してアンカー間隔を広げるとマスクは小さくなり、狭めると大きくなる。
- アンカー線の角度差を打ち消す方向にマスクが回転する。

方向はマスクのローカル座標。両アンカーを同じ点にはしない。
目の距離に合わせる等方scaleなので、顔とPNGの縦横比の違いは残る。

## テスト・CI

```sh
brew install swiftlint xcodegen editorconfig-checker
editorconfig-checker
swiftlint lint --strict --no-cache
xcodegen generate
xcodebuild \
  -project LuchadorCam.xcodeproj \
  -scheme LuchadorCam \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath .build \
  test
```

純粋な座標・transform計算の6テストで、テストバンドルはアプリを起動しない。
GitHub ActionsはPR・mainへのpush・手動実行でEditorConfig検査 → lint → 生成 → build/testを行う。
macOS 26ランナーの標準Xcodeを使用し、HomebrewでEditorConfig Checker・SwiftLint・XcodeGenを導入する。
ツールのバージョンはログへ出力するが、厳密な固定はしない。
整形規則は`.editorconfig`に定義し、`editorconfig-checker`でGit管理下のテキストファイルを検査する。
SwiftLintは標準ルールに加えて
`indentation_width`で4スペースのインデントを検査し、`function_body_length`のみ無効にする。

CodeQLはAdvanced setupを使用する。XcodeGenで生成後、manualモードでSwiftをビルド・解析する。
Swift・entitlements・`project.yml`・workflowを変更したmainへのpush、週次、手動実行が対象。
PRではCodeQLを実行せず、通常CIでlint・build/testを確認する。
READMEや画像だけのpushではCodeQLを省略する。週次・手動実行では変更ファイルにかかわらず解析する。
CodeQLの指摘がマージ後に判明する運用とし、Default setupとの併用はしない。

## 実機確認

CIはカメラやVisionの実機検証を代替しない。以下を使用する画像・カメラで確認する。

1. 数分間使用し、映像や追従が止まらず、時間とともに遅延が増えないか確認する。
2. 顔を左右・前後へ動かし、首を傾け、ウィンドウを縦長・横長にする。
3. 顔をカメラの画角外へ出すと消え、戻すとマスクが復帰することを確認する。
4. ウィンドウを閉じるとカメラが停止し、再起動して使えることを確認する。
5. 可能な範囲で権限拒否・未接続・片目欠落を試す。
   目を覆ってもVisionが位置を推定する場合がある。

## 制限

- 2D追従のみ。横顔の遠近変形や遮蔽物は再現しない。
- 最大10Hz、smoothingなし。速い動きでは遅延や揺れが出る。
- 最大の顔1件のみ。人物の継続識別はしない。
- システム既定カメラのみ。選択UIや切断後の自動復旧はない。
- 任意のカメラ・姿勢・対応OS全バージョンでの動作は未検証。
- 仮想カメラ、Google Meet、OBS連携、Core Image、Metal、3Dは未実装。

## ライセンス

コードとドキュメントは[MIT License](LICENSE)。
`assets/mask.png`はAI生成のサンプル画像で、このコード向けMIT Licenseの対象外。
画像の別途の再利用ライセンスは設定していない。
