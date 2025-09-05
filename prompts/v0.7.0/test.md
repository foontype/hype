task build を実行して build/hype をビルドします

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