# 検証記録

日付: 2026-10-30 JST。検証したbuild source: `4bb29b6df5fb208ef7c292c6a2afc0319409c465`。
[GitHub Actions run 40907084471](https://github.com/leaguejp/ios-flex-app/actions/runs/40907084471): **SUCCESS**。以後の変更は説明文・検証記録のみ。

## 実行環境とcommand

- ローカル: Windows / Python 3.12.9。iOS SDKや実機接続はなし。
- CI: macos-15-arm64、Xcode 16.4 (16F6)、Apple clang 17.0.0 (clang-1700.0.13.5)、公式iPhoneOS SDK 18.5。
- Theos: `dd5c14bb9d91311e221d51b5bfb8c9e5948156db`＋固定submodules。

```sh
# 親リポジトリのCI
bash templates/dopamine-ios15-rootless/tools/bootstrap.sh
python3 -m unittest discover -s tests -p test_tweak_template.py -v
bash templates/dopamine-ios15-rootless/tools/build.sh

# 単独プロジェクトにコピーした後は
bash tools/build.sh
python3 tools/validate.py --deb packages/com.example.dopaminetemplate_0.1.0_iphoneos-arm64.deb --report artifacts/package-report.json
```

完成debをActionsからダウンロードし、ローカルでも同じ`tools/validate.py --deb ...`を実行: PASS。

## 結果

| 項目 | 結果 |
|---|---|
| filter / guard、domain、key、通知、bundle/class名の対応 | PASS |
| 検証用テスト | 4件成功。対応関係の破損、異なるdeployment、fat slice重複/境界も拒否 |
| Tweakのビルド | arm64 / arm64eとも成功 |
| Settings用bundleのビルド | arm64 / arm64eとも成功 |
| minimum deployment | 各sliceでiOS 15.5、iOS device platformを確認 |
| package | com.example.dopaminetemplate / 0.1.0 / iphoneos-arm64 / Installed-Size 344 |
| arと圧縮 | debian-binary 2.0、control.tar.gz、data.tar.gz、gzip |
| tar | 各headerがustar。GNU/PAX拡張headerなし |
| filesystem layout | payloadがrootless prefix以下。filter / PreferenceLoader entry / bundle resources確認 |
| dependencies | Cephei、Substrate互換framework、UIKit/Foundation。Preferences.frameworkはbundle側のみ |
| 署名 | 各sliceのLC_CODE_SIGNATUREと範囲を確認。実機での署名受入れ検証ではない |
| rpath | 各sliceを別途読取り。Theos生成のprefixと@loader_path/.jbrootがあることを確認 |
| 実機Settings表示・保存・注入・ON/OFF反映 | **未検証** |

[完成deb検査結果](validation/package-report.json)、[rpath読取り結果](validation/rpaths-review.json)。検査scriptはDependenciesと署名commandを確認しますが、端末上のlibrary解決や署名の有効性までは確認しません。

完成deb SHA-256: `d0fb66e3950ff5480d5d5321f3ce70e2339171705d572cb310e2805e13c02e57`。

## ビルド時に確認・修正した点

最初の[run 40905806766](https://github.com/leaguejp/ios-flex-app/actions/runs/40905806766)はPreference Bundleのlinkで失敗。公開SDKにPreferences.frameworkのlink情報がなかったため、必要symbolだけの自作tbdを追加しました。Apple framework binaryやSDKをvendorしていません。古いTheosの`-multiply_defined suppress`もsubprojectから除去し、warningを無条件に隠す方式は採っていません。

[run 40906203322](https://github.com/leaguejp/ios-flex-app/actions/runs/40906203322)で成功後、toolchain versionを記録する出力を追加し、上記最終runでも成功。最終buildにはcompiler/linkerのwarningなし。artifact uploader側のNode deprecation noticeは、生成するtweakのABIやlinkのwarningではありません。

この雛形を基に機能を追加した場合は、元の検証結果を新しい機能の成功証拠として流用せず、必要なbuildと実機確認を追記してください。
