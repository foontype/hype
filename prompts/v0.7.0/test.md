task build を実行して build/hype をビルドします

エラーが発生した場合は TRACE=true を hype コマンド実行時につけてエラー箇所を特定してください

* 動作確認手順

./build/hype repotest use repo https://github.com/foontype/hype --path prompts/nginx-example

./build/hype list
  * repotest が表示されること

./build/hype repotest init

./build/hype repotest helmfile template

./build/hype repotest helmfile apply

./build/hype repotest helmfile destroy

./build/hype repotest deinit

./build/hype repotest unuse

./build/hype list
  * repotest が表示されないこと