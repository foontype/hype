cd examples/nginx

../../src/hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-value, test-nginx-secrets がないことを確認

../../src/hype test init

../../src/hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-value, test-nginx-secrets があることを確認

../../src/hype test helmfile template
  * デバッグログで helmfile template 実行時の引数に、--state-value-file オプションで state value configmap の一時ファイルが指定されていること
  * デバッグログで helmfile template 実行時の引数に、--state-value-file オプションで hype.currentDirectory を含む一時ファイルが指定されていること
  * デバッグログで state value configmap の一時ファイルに、state value file の元になった configmap と同等の構造が JSON ではなく YAML で出力されており、トップキーが values でないこと
  * デバッグログで helmfile section の一時ファイルに、hypefile.yaml の helmfile section の内容が出力されていること
  * デバッグログで helmfile section の一時ファイルの拡張子が .yaml.gotmpl であること
  * デバッグログで hype section の一時ファイルに、hypefile.yaml の hype section の内容が出力されていること

../../src/hype test helmfile apply
  * kubectl を使って nginx がアップしていること

../../src/hype test helmfile destroy
  * kubectl を使って nginx がダウンしていること

../../src/hype test deinit

../../src/hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-value, test-nginx-secrets がないことを確認
