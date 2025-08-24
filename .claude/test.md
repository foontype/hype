cd examples/nginx

../../src/hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-value, test-nginx-secrets がないことを確認

../../src/hype test init

../../src/hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-value, test-nginx-secrets があることを確認

../../src/hype test helmfile apply
  * kubectl を使って nginx がアップしていること
  * デバッグログで helmfile の引数を表示したとき --state-value-file オプションが指定されていること

../../src/hype test helmfile destroy
  * kubectl を使って nginx がダウンしていること

../../src/hype test deinit

../../src/hype test check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-value, test-nginx-secrets がないことを確認
