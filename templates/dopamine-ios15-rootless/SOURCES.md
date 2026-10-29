# 調査した一次資料と公開実装

確認日: 2026-10-30 JST。repositoryは実際に取得して該当fileを読みました。調査用checkoutは本雛形へ同梱せず、implementationのvendorはしていません。ライブラリは端末側の依存パッケージとして使用します。

## 公式文書

| 資料 | 確認した内容 |
|---|---|
| [Theos Rootless](https://theos.dev/docs/rootless) | rootless scheme、package architecture、prefix、@rpath、rootless.h、macOSでのnew arm64e ABI |
| [Theos arm64e Deployment](https://theos.dev/docs/arm64e-deployment) | Apple platform binaryとarm64e、iOS 14 / Xcode 12を境にしたABIの区別 |
| [Theos Logos Syntax](https://theos.dev/docs/logos-syntax) | hook group、ctor/init、origの使用 |
| [Theos configuration](https://theos.dev/docs/configuration) | ARCHS/TARGETとsubprojectへの設定共有 |
| [Apple UserDefaults suiteName](https://developer.apple.com/documentation/foundation/userdefaults/init(suitename:)) | suiteを指定してもApp Sandboxの他アプリ設定を無条件に共有できない |

## 公開tweakと関連プロジェクト

| Project / 確認commit | 読んだfile | 本テンプレートへの判断 |
|---|---|---|
| [Choicy](https://github.com/opa334/Choicy/tree/b6c9297328a73cff85e69df525afbbd88eeec10c) `b6c9297328a73cff85e69df525afbbd88eeec10c` | Makefile、ChoicyPrefs/Makefile、entry.plist、CHPListController.m、ChoicySB/ChoicySB.plist | 本体とSettings bundleの分離、Preferences.framework、メニューentry、変更通知、注入制御。ソースcontrolの古いArchitecture値だけを真似せず、rootless schemeと完成debを見る |
| [EvilScheme](https://github.com/0xkuj/EvilScheme/tree/a68067a1e7255519eb70bff7a5cab9cd442278d3) `a68067a1e7255519eb70bff7a5cab9cd442278d3` | Makefile、Prefs/Makefile、Prefs/entry.plist | arm64/arm64eと別Preference Bundle、依存libraryを含む構成。SDK/targetや独自ライブラリ、強制respring ruleはそのまま移植しない |
| [PreferenceLoader（実機用fork）](https://github.com/dhinakg/preferenceloader/tree/c788b66e8f1acdac3b48d0eb12929d7dbf1ad421) `c788b66e8f1acdac3b48d0eb12929d7dbf1ad421` | PreferenceLoader.plist、Makefile、Tweak.xm、prefs.xm | Settingsへの注入とbundle検出の経路。Makefileにはupstream Theos向けではない旨の注意があり、本雛形のbuild設定としてコピーしていない |
| [ElleKit](https://github.com/tealbathingsuit/ellekit/tree/1017a0d09606ea49ba8bc4d6cccc530d372e640e) `1017a0d09606ea49ba8bc4d6cccc530d372e640e` | launchd/Tweak.swift、Implementations.swift、packaging/control、Makefile | Bundles/Executablesの読取りと対象判定、Dopamineの注入基盤、Substrate互換の提供 |
| [Cephei](https://github.com/hbang/libcephei/tree/7ad69a903cffa0b8240f8eb1a9afb27c15d8fe57) `7ad69a903cffa0b8240f8eb1a9afb27c15d8fe57` | README.md、main/HBPreferences.h、HBPreferencesCore.m、HBPreferences.m | Settingsとsandboxed appの設定backend、domain/ReloadPrefs通知、mobileでの書込み条件、ws.hbang.common依存 |
| [Theos templates](https://github.com/theos/templates/tree/6c3944e281c4726f1383755d0fbb642840312d28) `6c3944e281c4726f1383755d0fbb642840312d28` | ios/preference_bundle、ios/tweak_with_simple_preferences | PSListController / Root.plist / entryの最小構造。古いdeployment targetをそのまま採用しない |
| [Dopamine](https://github.com/opa334/Dopamine/blob/13b26789842922cd4bd9fb5f30b3878d7e67ff0b/README.md) `13b26789842922cd4bd9fb5f30b3878d7e67ff0b` | README.md | 通常rootlessの対象。最新全OS対応表の再現を目的とせず、ユーザーのiOS 15.5環境を前提にする |

PoomSmart/PreferenceLoaderというURLは確認時に**preferenceloader-sim**へ転送されました。Simulator専用のforkを実機用PreferenceLoaderとして案内しないよう、実機用forkを別に確認しています。

`CydiaSubstrate.framework`がlink dependenciesへ出ても、Dopamineへ旧Substrateを追加インストールするという意味ではありません。確認したElleKitのpackaging/controlはmobilesubstrateを提供し、MakefileはCydiaSubstrate互換frameworkのlinkを配置しています。この雛形はDopamine用としてellekitを依存に宣言します。

## 自作link stubとライセンス

`sdk-stubs/Preferences.framework/Preferences.tbd`は、使用する3つのsymbol名とinstall nameのみを記述したlink用テキストです。AppleのSDK・framework binary・実装を配布するものではありません。ヘッダはTheosの既存headersを利用します。Preferencesの実装は実機OSが提供します。

テンプレートのソースは新規作成。外部実装はコピーしていません。Cepheiは実行時依存で、その導入先・利用条件は上流README/LICENSEを参照してください。上流を改変・vendorする場合は、各projectのライセンス確認と必要な表示を別途行ってください。
