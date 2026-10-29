# 次のtweak作成時に渡す要件テンプレート

以下をコピーし、`<...>`を埋める。未決定項目は「未確認」とし、確認結果と区別する。

```text
目的: <何を、どの画面/操作で変更するか>
対象端末: iPhone 11 / A13
対象OS: iOS 15.5 <必要ならbuild番号>
Jailbreak: Dopamine <version> / 通常rootless
RootHide対応: なし <必要なら別scheme・別成果物として指定>

Package ID: <逆DNS形式の固有ID>
Tweak binary名: <固有名>
設定domain: <自分の独自domain>
設定変更通知: <domain>/ReloadPrefs
対象アプリ/プロセス: <bundle identifier、実行ファイル名、version>
対象外: <SpringBoard、daemon、extension等>

Architecture:
- deb: iphoneos-arm64
- Mach-O: 既定arm64 + arm64e
- Settings/SpringBoard等Apple platform processへロードするものはarm64e対応を確認
- iOS 14以降のarm64e ABI、公式Xcode、deployment target 15.5

設定UI:
- Settings内のPreference Bundle / PreferenceLoaderを使う
- <項目名、型、初期値、範囲>
- <即時反映、アプリ再起動が必要な変更、respringが必要な変更の区別>
- 書く側/読む側で同じbackendとdomainを使う
- 他プロセスのNSUserDefaultsが自動的に共有されるとは仮定しない

注入・hook:
- ElleKitの通常tweak injection。対象bundle IDの限定filter
- <class、instance/class method、selector、確認したsignature>
- <元実装をいつ呼ぶか、main threadで行う処理、例外時の挙動>
- private class未ロード、OS差、競合時の失敗方法
- 不要な全UIKit注入、remote injection、権限付与を導入しない

ビルド/配布:
- rootless Theos、固定revision、macOS CI
- sourceの/var/jb直書きを避け、resourceはbundleまたはrootless API
- layoutにprefixを重複させない
- 完成debの両CPU、dependency/rpath、署名、metadata、gzip/ustarを検査
- 秘密鍵、証明書、端末identifier、外部SDK実体をcommitしない

受入条件:
- Settingsに項目が出て、画面を開け、値が保存/再読込される
- 指定アプリだけへ注入される
- <期待する変更と元に戻る条件>
- <ログ、設定export、クラッシュ時復旧など必要な機能>
- build/packageと実機検証を分けて報告する
- 実機未確認なら成功と断定しない

参考雛形: templates/dopamine-ios15-rootless
参考資料: 同ディレクトリのSOURCES.md
```
