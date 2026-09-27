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

`assets/mask.png`は、使用者の息子が描いた絵をもとにした
水色・赤のマスク画像。画像は1254×1254の透過PNGで、背景・目穴・口が透過している。

`LuchadorCam/MaskGeometry.swift`に画像の左上原点の正規化アンカーをまとめている。

- `leftEyeAnchor = (0.350, 0.554)`、約(439, 695)ピクセル
- `rightEyeAnchor = (0.650, 0.554)`、約(815, 695)ピクセル

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

## OBS経由でGoogle Meetに映す（暫定的な検証方法）

アプリ側の変更なしで、次の経路でマスク付き映像をMeetへ送れる。

```text
LuchadorCam → OBSのWindow Capture → OBS Virtual Camera → Google Meet
```

この方法ではLuchadorCamとOBSの両方を起動しておく必要がある。
OBSはアプリのビルドや単体利用には不要。現時点では自作Camera Extensionを実装せず、
まずOBS経由で数回使い、追従品質と使い勝手を確認する。
OBSの起動・キャプチャ設定が日常利用の負担になり、Meetから直接選べるカメラが必要になったら、
映像の受け渡し・拡張の導入・権限管理を含むCamera Extensionの開発を検討する。

### 初回設定

1. [OBS Studio](https://obsproject.com/download)をインストールする。
   Homebrewを使う場合は`brew install --cask obs`でもよい。
2. LuchadorCamを起動し、実カメラの映像とマスクが表示されることを確認する。
3. OBSにmacOSの画面収録権限を許可し、要求された場合はOBSを再起動する。
   この構成ではOBSによる実カメラ・マイクの取得や、入力監視の権限は不要。
4. OBSの設定 → 映像で、基本（キャンバス）解像度・出力解像度をともに1280×720、FPSを30にする。
5. シーンを作り、ソースに「macOS Screen Capture」を追加する。
   取得方法を「Window Capture」にし、LuchadorCamのウィンドウを選ぶ。カーソル表示はOFFにする。
6. ソースの変換設定で、タイトルバーが入る場合は上端をクロップする。
   「画面に合わせる（Fit to Screen）」で縦横比を保って配置し、余白は黒帯のまま許容する。
   クロップ量は画面の表示倍率などで変わるため、OBSのプレビューを見て調整する。
7. Studio ModeをOFFにし、Virtual Cameraの出力を「Program（Default）」にする。
   「Start Virtual Camera」を押す。録画・ストリーミングの開始は不要。
8. 初回にOBSのシステム拡張の有効化を求められたら、システム設定で許可して認証する。
   検証したmacOS 27.0では「一般 → ログイン項目と機能拡張 → アプリ別 → OBS → Media Extension」だった。
   有効化後はOBSを再起動し、Virtual Cameraを開始し直す。

画面収録権限はOS上では画面全体も取得できる権限だが、OBSのソースはLuchadorCamのウィンドウに限定する。
画面全体の取得へ切り替えて調査するときは、先にVirtual Cameraを停止する。
設定名はOS・OBSのバージョンで異なる。詳しくはOBS公式の
[macOS Screen Capture](https://obsproject.com/kb/macos-screen-capture-source)と
[Virtual Camera Troubleshooting](https://obsproject.com/kb/virtual-camera-troubleshooting)を参照する。

### Meetでの確認と終了

1. ChromeでMeetを開き、カメラに「OBS Virtual Camera」を選ぶ。
   ブラウザーのカメラアクセスを許可し、背景ぼかしなどの映像エフェクトはOFFにする。
   映像だけの検証ではマイクをOFFにし、マイク権限は追加しなくてよい。
2. Macで会議に参加し、別端末も同じ会議へ参加させる。
   別端末のカメラ・マイクをOFF、スピーカーを消音にして、Macからのマスク付き映像を確認する。
   同じアカウントで切り替え画面が出る場合は「その他の参加方法」から
   「このデバイスでも参加（Join here too）」を選ぶ（[Google公式の説明](https://support.google.com/meet/answer/14762432?hl=en)）。
3. 5分程度、顔の左右移動・近づく／離れる・首の傾き・画角外からの復帰を試す。
   別端末で映像停止や遅延の増加がないか確認する。
4. MeetのカメラをOFFにしてLuchadorCamを再起動し、実カメラの映像が出ることを確認する。
   OBSが再取得できなければ、ソースの対象ウィンドウを選び直す。
   OBSのプレビューを確認してからMeetのカメラをONに戻す。
5. 終了時はMeetから退出し、OBSの「Stop Virtual Camera」を押してLuchadorCamを終了する。
   カメラの使用表示が消えることも確認する。

ウィンドウをリサイズすると映像の切り取り範囲やOBS側の余白が変わる可能性がある。
検証中は大きさを固定し、最小化やフルスクリーン切り替えを避ける。
顔枠・目のマーカー・説明文も配信に含まれる。
表示切替は[Issue #1](https://github.com/toku345/lucha-cam/issues/1)で対応する。
マスクは顔や目を検出できないと消えるため、素顔を隠す用途は保証しない。

### 検証結果（2026-09-26）

- 環境: Apple Silicon、macOS 27.0、OBS 32.2.2、Chrome 154。
- 確認済み: コード変更なしでカメラ映像・PNGマスク・デバッグ表示をウィンドウ取得し、
  OBS Virtual Camera経由でMeetへ送信。別端末でマスク付き映像を受信できた。
- 設定: 1280×720 / 30fps、タイトルバーをクロップ、縦横比を維持して配置。
- 終了: Meet退出、Virtual Camera停止、LuchadorCam終了を確認した。
- 未確認: 時間を測った5分間の連続動作、遅延の定量評価、アプリ再起動後の再取得、
  最小化・リサイズ・他ウィンドウによる遮蔽の影響。長時間安定性の保証ではない。

## 制限

- 2D追従のみ。横顔の遠近変形や遮蔽物は再現しない。
- 最大10Hz、smoothingなし。速い動きでは遅延や揺れが出る。
- 最大の顔1件のみ。人物の継続識別はしない。
- システム既定カメラのみ。選択UIや切断後の自動復旧はない。
- 任意のカメラ・姿勢・対応OS全バージョンでの動作は未検証。
- アプリ自身の仮想カメラ出力・OBS専用連携API、Core Image、Metal、3Dは未実装。
  Meetでの利用は上記のOBSウィンドウ取得による暫定構成。

## ライセンス

コードとドキュメントは[MIT License](LICENSE)。
`assets/mask.png`は息子の絵をもとにしたマスク画像で、このコード向けMIT Licenseの対象外。
画像の別途の再利用ライセンスは設定していない。
