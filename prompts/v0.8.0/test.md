### テスト準備

テスト準備やテスト手順実施中にエラーが発生した場合はテストを停止し、ユーザーに報告してください。

task build を実行して build/hype をビルドします
> task build

空の hypefile.yaml を設置して、キャッシュディレクトリを固定します。
> touch hypefile.yaml

いくつかの主要コマンドもあることを確認します。

> which kubectl

> which helm

> which helmfile

> which task

### プロジェクト開発機能 テスト手順

> cd prompts/nginx-example
  * examples に移動します

> cd prompts/nginx-example && ../../build/hype test releases check
  * $? が 1 であること
  * もし $? が 0 の場合（既存リソースが残っている場合）、以下を実行してリトライ:
    * `../../build/hype test down` でリソースをクリーンアップ
    * 再度 `../../build/hype test releases check` を実行して $? が 1 であることを確認

> cd prompts/nginx-example && ../../build/hype test trait set test-trait

> cd prompts/nginx-example && ../../build/hype test trait
  * test-trait と表示されること

> cd prompts/nginx-example && ../../build/hype test trait check test-trait
  * $? が 0 であること

> cd prompts/nginx-example && ../../build/hype test trait check wrong-test-trait
  * $? が 1 であること

> cd prompts/nginx-example && ../../build/hype test resources check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-values, test-nginx-secrets がないことを確認

> cd prompts/nginx-example && ../../build/hype test parse section hype
  * hypefile.yaml の hype セクションが表示されること

> cd prompts/nginx-example && ../../build/hype test parse section helmfile
  * hypefile.yaml の helmfile セクションが表示されること

> cd prompts/nginx-example && ../../build/hype test init

> cd prompts/nginx-example && ../../build/hype test resources check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-values, test-nginx-secrets があることを確認

> cd prompts/nginx-example && ../../build/hype test template state-values test-nginx-state-values
  * configmap に保存された data.values 以下の構造が表示できること

> cd prompts/nginx-example && ../../build/hype test helmfile build
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

> cd prompts/nginx-example && ../../build/hype test helmfile template
  * デバッグログで helmfile template 実行時の引数に、--state-values-file オプションで state value configmap の一時ファイルが指定されていること
  * デバッグログで helmfile template 実行時の引数に、--state-values-file オプションで hype.currentDirectory を含む一時ファイルが指定されていること
  * デバッグログで state value configmap の一時ファイルに、state value file の元になったconfigmap と同等の構造が出力されていること
  * デバッグログで helmfile section の一時ファイルに、hypefile.yaml の helmfile section の内容が出力されていること
  * デバッグログで helmfile section の一時ファイルの拡張子が .yaml.gotmpl であること
  * デバッグログで hype section の一時ファイルに、hypefile.yaml の hype section の内容が出力されていること

> cd prompts/nginx-example && PATH="$(cd ../../build && pwd):${PATH}" ../../build/hype test task vars
  * タスク出力の HYPE_NAME の値が test であること
  * タスク出力の HYPE_CURRENT_DIRECTORY の値が test であること
  * タスク出力の HYPE_TRAIT の値が test-trait であること

> cd prompts/nginx-example && ../../build/hype test helmfile apply
  * kubectl から nginx がアップしていることを確認する

> cd prompts/nginx-example && ../../build/hype test releases check
  * $? が 0 であること（リリースがデプロイされているため）
  * "All releases are present" メッセージが表示されること

> cd prompts/nginx-example && ../../build/hype test helmfile destroy
  * kubectl から nginx がダウンしていることを確認する

> cd prompts/nginx-example && ../../build/hype test up
  * kubectl から nginx がアップしていることを確認する

> cd prompts/nginx-example && ../../build/hype test down
  * kubectl から nginx がダウンしていることを確認する

> cd prompts/nginx-example && ../../build/hype test deinit

> cd prompts/nginx-example && ../../build/hype test resources check
  * kubectl を使って、test-nginx-configmap, test-nginx-state-values, test-nginx-secrets がないことを確認

> cd prompts/nginx-example && ../../build/hype test trait unset

> cd prompts/nginx-example && ../../build/hype test trait
  * test-trait と表示されないこと

### リポジトリバインディング機能 テスト手順

#### 1. バージョン確認テスト

> ./build/hype --version
  * バージョン番号が表示されること

#### 2. ヘルプ機能テスト

> ./build/hype myapp repo --help
  * repo サブコマンドのヘルプが表示されること
  * bind, unbind, update, status の各コマンドが記載されていること

#### 3. 初期状態確認テスト

> ./build/hype myapp repo
  * "No repository bound" または類似のメッセージが表示されること

#### 4. リポジトリバインドテスト

> ./build/hype myapp repo bind foontype/hype --path prompts/nginx-example
  * バインド成功のメッセージが表示されること
  * kubectl でConfigMap hype-repos が作成されていること

> ./build/hype myapp repo check foontype/hype --path prompts/nginx-example
  * $? が 0 を返すこと

> ./build/hype myapp repo check foontype/hype2
  * $? が 1 を返すこと

#### 4-1. バインドしたリポジトリの使用テスト

> ./build/hype myapp parse section hype
  * prompts/nginx-example/hypefile.yaml の hype section 表示されること

#### 5. バインド状態確認テスト

> ./build/hype myapp repo
  * バインドされたリポジトリURL https://github.com/foontype/hype.git が表示されること
  * パスが promots/nginx-example であること
  * バインド日時が表示されること

#### 6. 無効なURL拒否テスト

> ./build/hype myapp repo bind invalid-url
  * エラーメッセージが表示されること
  * 無効なURLが適切に拒否されること

> ./build/hype myapp repo bind not-a-git-url.com
  * エラーメッセージが表示されること
  * .git で終わらないURLが適切に拒否されること

#### 7. リポジトリ更新テスト

> ./build/hype myapp repo update
  * 更新処理が実行されること
  * 最新の更新日時が表示されること

#### 8. 重複バインドテスト

> ./build/hype myapp repo bind https://github.com/example/test.git
  * 既存のバインドが上書きされること
  * 新しいリポジトリURL（https://github.com/example/test.git）が表示されること

#### 9. ConfigMap確認テスト

> kubectl get configmap hype-repos -o yaml
  * myapp のエントリが存在すること
  * url フィールドに正しいリポジトリURLが設定されていること
  * bound_at フィールドにタイムスタンプが設定されていること
  * updated_at フィールドにタイムスタンプが設定されていること

#### 10. リポジトリアンバインドテスト

> ./build/hype myapp repo unbind
  * アンバインド成功のメッセージが表示されること

#### 11. アンバインド後状態確認テスト

> ./build/hype myapp repo
  * "No repository bound" または類似のメッセージが表示されること

> kubectl get configmap hype-repos -o yaml
  * myapp のエントリが削除されていること、または空の状態であること

#### 12. エラーハンドリングテスト

> ./build/hype myapp repo unbind
  * 既にアンバインド状態でunbindを実行した場合のエラーメッセージが表示されること

> ./build/hype myapp repo update
  * バインドされていない状態でupdateを実行した場合のエラーメッセージが表示されること

#### 13. kubectl未インストール環境テスト

kubectl が利用できない環境では以下をテスト:

> ./build/hype myapp repo bind https://github.com/foontype/hype.git
  * 適切なエラーメッセージが表示されること
  * kubectl が必要であることが明示されること

### テスト後クリーンアップ

> kubectl delete configmap hype-repos --ignore-not-found=true
  * テスト用ConfigMapを削除