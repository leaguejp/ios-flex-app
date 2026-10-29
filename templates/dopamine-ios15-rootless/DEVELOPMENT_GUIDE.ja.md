# Dopamine rootless / iOS 15.5 開発要件

調査日: 2026-10-30 JST。基準はiPhone 11。一般的なtweakとSettings内Preference Bundle向け。ホーム画面アプリやdaemonは別の実行・署名要件を持ちます。

## 1. ビルド、CPU、packageの条件

- `THEOS_PACKAGE_SCHEME=rootless`を`common.mk`より前に設定する。
- 基準設定は`ARCHS = arm64 arm64e`、`TARGET = iphone:clang:latest:15.5`。このデプロイ先は15.5以上のみ。15.0もサポートする場合は使用APIを確認して変更する。
- A12以降のApple platform binaryへの注入ではarm64eを考慮する。Settings用bundleも同様。端末がA13だから第三者アプリまで全部arm64e、という判断はしない。
- iOS 14以降のarm64e ABIでビルドする。Xcode 11系の旧ABIをそのまま15.5へ流用しない。ここではmacOS＋公式Xcode＋固定Theosで再現する。
- 通常rootlessのdeb architectureは`iphoneos-arm64`。`ARCHS`やMach-OのCPUとは別の値。`iphoneos-arm64e`へ変更してもCPUのコンパイル設定は変わらない。
- `lipo -archs`だけでarm64eの新旧ABIまで保証できない。toolchainとdeployment targetも記録し、最後は対象OSでロードを確認する。
- 外部dylib/frameworkにも使用するCPU sliceとrootless互換のinstall name / rpathが必要。自作コードだけfatでも依存が片方しかなければ失敗する。

出典: [Theos arm64e](https://theos.dev/docs/arm64e-deployment)、[rootless](https://theos.dev/docs/rootless)。

## 2. filesystemとリンク

Makefileの`INSTALL_PATH`や`layout/`には通常の`/Library/...`を記述し、Theosへprefix付与を任せる。`layout/var/jb/Library/...`を重ねて二重prefixにしない。

| 内容 | プロジェクト内で指定する論理path |
|---|---|
| tweakと同名filter | Theosの`tweak.mk`に任せる。通常は`/Library/MobileSubstrate/DynamicLibraries`系 |
| Preference Bundle | `/Library/PreferenceBundles/ExamplePrefs.bundle` |
| Settingsのメニューentry | `/Library/PreferenceLoader/Preferences/ExamplePrefs.plist` |
| 同梱resourceの参照 | bundleからの相対参照を優先。絶対pathが必要なら`rootless.h` |

通常Dopamineではdebに`var/jb/...`が入る。実行時のprefixやsymlink解決まで自前で固定しない。必要なC / ObjC path変換はTheosの`ROOT_PATH` / `ROOT_PATH_NS`を使う。すべてのユーザーデータpathへ機械的にprefixを付けるのも誤りで、preferencesは選択したbackendのAPIに任せる。[Theos rootless](https://theos.dev/docs/rootless)

RootHideは本テンプレートの対象外。名前を変えるだけ、通常Theosのままpackage architectureだけ変更する、通常rootlessのprefixをコピーする、といった方法では扱わない。

## 3. Settings内の設定表示に必要な対応関係

1. **PreferenceLoader**がSettingsへ注入されていること。Settings bundle IDは`com.apple.Preferences`。Safe ModeやChoicy等でSettings側の注入を止めると表示できない。
2. `PreferenceLoader/Preferences/*.plist`に`entry`を配置する。`cell=PSLinkCell`、`bundle=ExamplePrefs`、`detail=ETRootListController`、`isController=true`等を対応させる。
3. `ExamplePrefs.bundle`の`CFBundleExecutable=ExamplePrefs`、`NSPrincipalClass=ETRootListController`が実際のbinary / ObjC classと一致すること。
4. そのclassが`PSListController`を継承し、`loadSpecifiersFromPlistName:@"Root" target:self`で実在するRoot.plistを読むこと。
5. bundleはSettingsでロード可能なCPU slice、署名、依存リンクを持つこと。private frameworkのPreferencesをリンクする。単にplistを置くだけではcustom controllerは実装されない。
6. Root.plistのswitchで`key`、`default`、`defaults`、`PostNotification`を保存backendと一致させる。

本体tweakのfilterにSettingsを追加する必要はありません。PreferenceLoaderがSettings内でPreference Bundleをロードする経路と、本体tweakが対象アプリへ注入される経路は別です。アイコンは任意で、追加するならentryのicon名とbundleのresourceを一致させます。ホーム画面アプリの登録に使うuicacheと、PreferenceLoaderの設定メニュー検出も別の処理です。

出典: [Choicyのentry](https://github.com/opa334/Choicy/blob/b6c9297328a73cff85e69df525afbbd88eeec10c/ChoicyPrefs/entry.plist)、[PreferenceLoaderのfilter](https://github.com/dhinakg/preferenceloader/blob/c788b66e8f1acdac3b48d0eb12929d7dbf1ad421/PreferenceLoader.plist)、[Theos preference bundle雛形](https://github.com/theos/templates/tree/6c3944e281c4726f1383755d0fbb642840312d28/ios/preference_bundle)。

## 4. 設定値をアプリへ反映する条件

Settingsと注入先は別プロセス。`NSUserDefaults.standardUserDefaults`ではホストアプリ自身のdomainを参照する。独自suite名を指定するだけで、sandboxを越えた読取りまで保証されるわけでもない。

本テンプレートは両側でCepheiの`HBPreferences`と同じ独自domainを使用する。bundle ID、Debian Package ID、preferences domainは役割が異なるが、domainを変更するときは書く側と読む側を必ず合わせる。

- `ExampleTweak_EXTRA_FRAMEWORKS = Cephei`、Preference Bundleにも同様のリンクを指定。
- `Depends: ws.hbang.common (>= 2.0)`を宣言。リンク用stubだけがPCにあっても、端末にframeworkがなければロードできない。
- 値を書いた後、`<domain>/ReloadPrefs`のDarwin通知を送る。通知に値や秘密情報を載せず、受信側がbackendから読み直す。
- Darwin通知を出しただけで保存成功・反映成功とは判断しない。対象プロセスのON/OFF読取りと再起動後の値を確認する。
- HBPreferencesの書込みはmobileユーザーで行う。本雛形はSettings側が書き、対象tweakは読む。
- 他のアプリの秘密情報やAppleのpreferencesを共有する仕組みとして使わない。sandbox内Apple domainにはHBPreferences自身の制約もある。

出典: [HBPreferencesの契約](https://github.com/hbang/libcephei/blob/7ad69a903cffa0b8240f8eb1a9afb27c15d8fe57/main/HBPreferences.h)、[Cephei導入方法](https://github.com/hbang/libcephei/blob/7ad69a903cffa0b8240f8eb1a9afb27c15d8fe57/README.md)、[Apple suiteNameのsandbox上の制限](https://developer.apple.com/documentation/foundation/userdefaults/init(suitename:))。

## 5. アプリへの注入要件

- Dopamineが有効なjailbreak状態でElleKitが稼働していること。パッケージのインストール完了と注入の成功は別。
- filter plistとdylibのbase nameを同じにし、Theosの正規layoutへ配置する。
- `Filter.Bundles`には表示名・実行ファイル名ではなくbundle identifierを指定する。App ExtensionやWebContent等の別プロセスは同じ対象とはみなさない。
- 本雛形は単一の具体的bundle IDで限定し、`%ctor`でも同じIDを照合する。`com.apple.UIKit`を指定すると、特定アプリ1つではなくUIKit利用プロセスへ広がる可能性がある。
- `Executables`が必要な場合はそのprocess名を別途調べる。BundlesとExecutablesを併記しても、常に論理ANDになるとは仮定しない。
- `INSTALL_TARGET_PROCESSES`はTheosインストール後の再起動対象を指定する設定であり、注入対象filterの代わりではない。
- 対象でChoicy等が注入を禁止していないか確認。バイナリ更新後は対象を完全終了して再起動する。既にロードされた旧dylibはファイルを置き換えるだけでは更新されない。
- `%hook`対象のclass/methodとsignatureは対象OS/アプリversionで確認する。constructor時点で未ロードのclassを前提にしない。
- メソッドの引数・戻り値・instance/class methodを一致させる。type encodingを見ただけで任意IMPへcastする設計にしない。UI変更はmain thread、元実装への委譲や例外挙動も設計する。

出典: [ElleKit filterの読取り](https://github.com/tealbathingsuit/ellekit/blob/1017a0d09606ea49ba8bc4d6cccc530d372e640e/launchd/Tweak.swift)、[ロード対象判定](https://github.com/tealbathingsuit/ellekit/blob/1017a0d09606ea49ba8bc4d6cccc530d372e640e/launchd/Implementations.swift)、[Choicy](https://github.com/opa334/Choicy)。

## 6. 権限・署名の境界

注入されたtweakとPreference Bundleはホストプロセス内で実行される。ファイルアクセス、IPC、寿命、sandboxの条件を引き継ぐ。tweak dylibへentitlementを書けば対象アプリの権限が増える、とは扱わない。

通常のこのtweakとPreference Bundleに、`task_for_pid`、remote injection、root実行、no-sandbox entitlementは不要。本体は既存ElleKitの注入経路を使う。ホーム画面アプリのno-container/no-sandbox等の設定を一般的tweakの必須条件としてコピーしない。独立アプリ・daemon・IPC brokerを追加する場合は別のプロセス設計と実機検証が必要。

## 7. 不具合の切り分け

| 症状 | 先に調べること |
|---|---|
| debを拒否される | architecture、rootless scheme、Depends、ar members、圧縮形式 |
| Settingsに項目がない | PreferenceLoaderの導入とSettingsへの注入、entryの配置、Settings再起動 |
| 項目はあるが開くとbundle読込みエラー | bundle名/class名、arm64e slice、依存framework不足、署名・dyldログ |
| 対象へ注入されない | 実bundle ID、filterの名前/内容、ElleKit、Choicy、Safe Mode、対象再起動 |
| constructorログは出るが効果がない | `%init`、class/method存在、該当コードが本当に呼ばれるか、初期OFF、ログ上限 |
| スイッチだけ変わって挙動が変わらない | domain/key/通知名、両側のbackend一致、対象の読取り値、sandbox、依存version |
| 設定が再起動で消える | 保存backend、書込ユーザー、アクセスエラー、保存先と読取り先の相違 |
| Settingsや対象がクラッシュする | 最初のdyldエラー、missing symbol/wrong architecture、hook signature、thread、例外 |

一度に複数のtweakを有効化して原因を推測するより、対象1つと本雛形のログで確認する。端末ログ/クラッシュログを残す。SpringBoardに変更する場合はSafe Modeから解除・削除できる復旧手順も用意する。

## 8. 完成条件

- tweakとPreference Bundleの各binaryに必要なCPU sliceがある。
- iOS deployment、link dependencies、rpath、署名commandを完成品で確認した。
- rootless debのarchitectureがiphoneos-arm64。gzip/ustar/ar membersを実データで確認した。
- Settingsに表示→開く→保存→再起動後に復元できた。
- 指定プロセスでconstructorとhookを確認し、対象外へ影響しない。
- ON/OFFが反映し、元動作が保持される。unsupportedなOS/アプリversionへの挙動を定めた。
- build/package検証と実機検証を別々に記録した。

## 完成品の追加確認command（macOS例）

検査scriptのJSONに加え、debを新しい作業ディレクトリへ展開して`lipo -archs`、`otool -L`、`otool -l`を使うと、slice・依存・LC_RPATH・LC_BUILD_VERSIONを個別に確認できます。検査用の展開場所とインストール先を混同しないでください。

```sh
# 作業用ディレクトリを作成してから、完成debをarで展開する
mkdir -p artifacts/unpacked
cd artifacts/unpacked
ar -x ../../packages/com.example.dopaminetemplate_0.1.0_iphoneos-arm64.deb
tar -xzf data.tar.gz
lipo -archs var/jb/Library/MobileSubstrate/DynamicLibraries/ExampleTweak.dylib
otool -L var/jb/Library/MobileSubstrate/DynamicLibraries/ExampleTweak.dylib
otool -l var/jb/Library/MobileSubstrate/DynamicLibraries/ExampleTweak.dylib
lipo -archs var/jb/Library/PreferenceBundles/ExamplePrefs.bundle/ExamplePrefs
otool -L var/jb/Library/PreferenceBundles/ExamplePrefs.bundle/ExamplePrefs
```

このdebは実機向けです。iOS Simulatorでそのまま動くbinaryではありません。Settings用PreferenceLoaderの実機ロード確認を、通常のSimulatorコンパイルだけで代替しないでください。
