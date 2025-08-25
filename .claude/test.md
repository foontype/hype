cd examples/nginx

../../src/hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-value, test-nginx-secrets がないことを確認

../../src/hype test init

../../src/hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-value, test-nginx-secrets があることを確認
  * configmap, secrets の内容が、YAML 形式であること
  * configmap, secrets の key に対する value の値が JSON 形式で展開されていないこと

../../src/hype test helmfile template
  * デバッグログで、helmfile template 実行時の引数に、--state-value-file オプションで state value configmap の一時ファイルが指定されていること
  * デバッグログで、helmfile template 実行時の引数に、--state-value-file オプションで hype.currentDirectory を含む一時ファイルが指定されていること
  * デバッグログで、state value configmap の一時ファイルについて、一時ファイルに configmap と同等の構造が出力されていること
  * デバッグログで、hype section の一時ファイルに、hypefile.yaml の hype section の内容が出力されていること
  * デバッグログで、helmfile section の一時ファイルに、hypefile.yaml の helmfile section の内容が出力されていること
  * デバッグログで、helmfile section の一時ファイルの拡張子が .yaml.gotmpl であること

../../src/hype test helmfile apply
  * kubectl を使って nginx がアップしていること

../../src/hype test helmfile destroy
  * kubectl を使って nginx がダウンしていること

../../src/hype test deinit

../../src/hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-value, test-nginx-secrets がないことを確認
