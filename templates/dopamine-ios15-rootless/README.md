# iOS 15.5 / Dopamine rootless 開発テンプレート

対象は通常の **Dopamine rootless**。RootHide 用ではありません。調査日: 2026-10-30 JST。

- [開発要件・設計判断・トラブル対応](DEVELOPMENT_GUIDE.ja.md)
- [次のtweakを依頼するときの要件テンプレート](NEW_PROJECT_CHECKLIST.ja.md)
- [調査した一次資料・公開tweakとcommit](SOURCES.md)
- [実行した検証と未検証項目](VALIDATION.md)

## 最初に区別する3つ

| 項目 | このテンプレート |
|---|---|
| 端末 | iPhone 11 / A13 / arm64e系端末 |
| 生成するMach-O | tweakもPreference Bundleも **arm64 + arm64e** |
| Debian package architecture | **iphoneos-arm64**。arm64e端末でもこの値 |

AppleのSettings/SpringBoardなどにロードするには、そのホストに合うarm64e sliceが必要です。一般アプリだけならarm64で足りる場合がありますが、Settings用bundleも一緒に作る本雛形は両sliceを標準にします。新旧arm64e ABIも区別します。[Theos: arm64e Deployment](https://theos.dev/docs/arm64e-deployment)、[Rootless](https://theos.dev/docs/rootless)。

## 同梱する最小機能

Settings内に「Dopamine Template」の設定画面を追加します。スイッチは初期OFF。指定アプリの`UIViewController -viewDidAppear:`で必ず元実装を呼び、ON時だけclass名を最大20回ログへ出します。設定変更はCepheiの通知経由で読取りへ反映します。外観・引数・戻り値は変更しません。

既定の対象は本リポジトリの **Atlas TestTarget** (`jp.league.runtimeatlas.fixture`)。そのアプリ自体はこのdebへ同梱しません。未導入なら注入先がないので、設定画面だけ表示されるのが正常です。自分のアプリに合わせてfilterと実行時guardを変更してください。

## コピーして使う

このディレクトリ全体を新しいプロジェクトへコピーします。Atlasの他のソース・ライブラリへの依存はありません。

```sh
cp -R templates/dopamine-ios15-rootless ../MyTweak
cd ../MyTweak
```

変更する場所:

| 設定 | 場所 |
|---|---|
| Package ID、名前、作者、version | `control` |
| Preference domain / key | `shared/TemplateConfig.h`、`prefs/Resources/Root.plist`の`defaults` / `key` |
| 設定変更通知 | Root.plistの`PostNotification`。domain + `/ReloadPrefs`に一致させる |
| 対象bundle ID | `ExampleTweak.plist`と`shared/TemplateConfig.h`の両方 |
| Settings bundle ID | `prefs/Resources/Info.plist`の`CFBundleIdentifier` |
| メニュー表示名・文言 | `layout/Library/PreferenceLoader/Preferences/ExamplePrefs.plist`、Root.plist |

`ExampleTweak`、`ExamplePrefs`、`ETRootListController`を改名する場合は、Makefile、filterファイル名、CFBundleExecutable、NSPrincipalClass、entryのbundle/detail、ソース、`tools/validate.py`の期待名もまとめて変更します。IDだけ変更する場合はバイナリ名の改名は不要です。

## macOSでビルド

Xcode本体とCommand Line Toolsが必要です。公式Xcode SDKを使用し、SDKの無断再配布物へ依存しません。

```sh
brew install ldid
export THEOS="$PWD/.tools/theos"
bash tools/bootstrap.sh     # 新規checkout用。既存ディレクトリには実行しない
bash tools/build.sh
```

Theosは検証対象のrevisionに固定。`tools/build.sh`はソース整合性→clean→両CPUのpackage生成→完成deb検査を行います。`make package`も使えますが、その後の検査を省かないでください。

Windows環境では、`ci/github-actions.yml`を新しいリポジトリの`.github/workflows/build.yml`へコピーすると同じビルドをmacOS runnerで実行できます。自己管理runnerを使う場合もXcodeの選択状態を記録してください。

```sh
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
python3 tools/validate.py
python3 tools/validate.py --deb packages/<Package ID>_<Version>_iphoneos-arm64.deb --report artifacts/package-report.json
```

`Preferences.framework`はprivate frameworkです。公開SDKのみでリンクできるよう、`sdk-stubs/`にPSListControllerの使用symbolだけを記載した自作のlink stubを入れています。Appleのframework実体やSDKは含みません。実機ではOS提供frameworkを使います。private APIの実在・挙動は実機確認が必要です。

## 実機で確認

Dopamineでjailbreak済み、ElleKit / PreferenceLoader / Cephei (`ws.hbang.common >= 2.0`)を導入した端末にdebをインストールします。

1. パッケージマネージャの依存関係エラーがないことを確認。
2. Settingsを完全終了して開き直す。「Dopamine Template」を開く。
3. 対象アプリのtweak injectionを有効にして完全終了→再起動する。
4. `[ExampleTweak] injected`を端末ログで確認。
5. SettingsでEnabledをON→対象へ戻り、画面を表示し直す。`appeared class=`を確認。
6. OFF後は新しいappearanceログが出ないことを確認。20回上限に達した場合は対象を再起動する。
7. Settingsと対象を再起動して設定保存を確認する。

単なる値変更のために毎回respringする設計にはしていません。バイナリ更新は対象アプリとSettingsを再起動します。SpringBoardへ対象を変更した場合は、そのプロセスの再起動・復旧手順も別途設計してください。

**CIでビルドできることと、実機の注入・Settings表示・sandbox内設定読取りが動くことは別です。** 実行済み範囲はVALIDATION.mdへ記録します。
