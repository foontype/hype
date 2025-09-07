### テスト準備

task build を実行して build/hype をビルドします
> task build

パス環境変数の先頭に build を追加します。すでにあるなら不要です。
重複している場合は、後方にあるものを取り除きます。
> export PATH="$(PWD)/build:${PATH}"

examples に移動します
> cd prompts/nginx-example

### テスト手順

> hype test trait set test-trait

> hype test trait
  * test-trait と表示されること

> hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-values, test-nginx-secrets がないことを確認

> hype test parse section hype
  * hypefile.yaml の hype セクションが表示されること

> hype test parse section helmfile
  * hypefile.yaml の helmfile セクションが表示されること

> hype test init

> hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-values, test-nginx-secrets があることを確認

> hype test template state-values test-nginx-state-values
  * configmap に保存された data.values 以下の構造が表示できること

> hype test helmfile build
  * test-discord-bot のリリースの values.autoHypeCurrentDirectory の値がカレントディレクトリであること
  * test-discord-bot のリリースの values.autoHypeName の値が test であること
  * test-discord-bot のリリースの values.autoHypeTrait の値が test-trait であること
  * test-discord-bot のリリースの values.hypeCurrentDirectoryValue の値がカレントディレクトリであること
  * test-discord-bot のリリースの values.hypeNameValue の値が test であること
  * test-discord-bot のリリースの values.hypeTraitValue の値が test-trait であること
  * test-discord-bot のリリースの values.strValue の値が "This is a pen." であること
  * test-discord-bot のリリースの values.numberValue の値が 12345 であること
  * test-discord-bot のリリースの values.boolValue の値が true であること
  * test-discord-bot のリリースの values.extraValue の値が "extra value" であること

> hype test helmfile template
  * デバッグログで helmfile template 実行時の引数に、--state-values-file オプションで state value configmap の一時ファイルが指定されていること
  * デバッグログで helmfile template 実行時の引数に、--state-values-file オプションで hype.currentDirectory を含む一時ファイルが指定されていること
  * デバッグログで state value configmap の一時ファイルに、state value file の元になったconfigmap と同等の構造が出力されていること
  * デバッグログで helmfile section の一時ファイルに、hypefile.yaml の helmfile section の内容が出力されていること
  * デバッグログで helmfile section の一時ファイルの拡張子が .yaml.gotmpl であること
  * デバッグログで hype section の一時ファイルに、hypefile.yaml の hype section の内容が出力されていること

> hype test task vars
  * タスク出力の HYPE_NAME の値が test であること
  * タスク出力の HYPE_CURRENT_DIRECTORY の値が test であること
  * タスク出力の HYPE_TRAIT の値が test-trait であること

> hype test helmfile apply
  * kubectl から nginx がアップしていることを確認する

> hype test helmfile destroy
  * kubectl から nginx がダウンしていることを確認する

> hype test up
  * kubectl から nginx がアップしていることを確認する

> hype test down
  * kubectl から nginx がダウンしていることを確認する

> hype test deinit

> hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-values, test-nginx-secrets がないことを確認

> hype test trait unset

> hype test trait
  * test-trait と表示されないこと

