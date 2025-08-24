cd examples/nginx

../../src/hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-value, test-nginx-secrets がないことを確認

../../src/hype test init

../../src/hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-value, test-nginx-secrets があることを確認

../../src/hype test helmfile apply
  * kubectl を使って nginx がアップしていること
  * デバッグログで helmfile の引数を表示したとき --state-value-file オプションが指定されていること
  * デバッグログで state value file の一時ファイルに、config map と同等の構造が出力されていること
  * デバッグログで helmfile section の一時ファイルに、hypefile.yaml の helmfile section の内容が出力されていること
  * デバッグログで hype section の一時ファイルに、hypefile.yaml の hype section の内容が出力されていること

../../src/hype test helmfile destroy
  * kubectl を使って nginx がダウンしていること

../../src/hype test deinit

../../src/hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-value, test-nginx-secrets がないことを確認
