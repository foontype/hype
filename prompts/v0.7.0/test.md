### テスト準備

task build を実行して build/hype をビルドします
> task build

空の hypefile.yaml を設置して、キャッシュディレクトリを固定します。
> touch hypefile.yaml

パス環境変数の先頭に build を追加します。すでにあるなら不要です。
> export PATH="$(cd ./build && pwd):${PATH}"

hype が利用できることを確認します。
> which hype

いくつかの主要コマンドもあることを確認します。

> which kubectl

> which helm

> which helmfile

> which task

### v0.7.0 リポジトリバインディング機能テスト

#### 1. バージョン確認テスト

> hype --version
  * HYPE CLI version 0.7.0 と表示されること

#### 2. ヘルプ機能テスト

> hype myapp repo --help
  * repo サブコマンドのヘルプが表示されること
  * bind, unbind, update, status の各コマンドが記載されていること

#### 3. 初期状態確認テスト

> hype myapp repo
  * "No repository bound" または類似のメッセージが表示されること

#### 4. リポジトリバインドテスト

> hype myapp repo bind https://github.com/foontype/hype.git --path prompts/nginx-example
  * バインド成功のメッセージが表示されること
  * kubectl でConfigMap hype-repos が作成されていること

#### 4-1. バインドしたリポジトリの使用テスト

> hype myapp parse section hype
  * prompts/nginx-example/hypefile.yaml の hype section 表示されること

#### 5. バインド状態確認テスト

> hype myapp repo
  * バインドされたリポジトリURL（https://github.com/foontype/hype.git）が表示されること
  * パスが promots/nginx-example であること
  * バインド日時が表示されること

#### 6. 無効なURL拒否テスト

> hype myapp repo bind invalid-url
  * エラーメッセージが表示されること
  * 無効なURLが適切に拒否されること

> hype myapp repo bind not-a-git-url.com
  * エラーメッセージが表示されること
  * .git で終わらないURLが適切に拒否されること

#### 7. リポジトリ更新テスト

> hype myapp repo update
  * 更新処理が実行されること
  * 最新の更新日時が表示されること

#### 8. 重複バインドテスト

> hype myapp repo bind https://github.com/example/test.git
  * 既存のバインドが上書きされること
  * 新しいリポジトリURL（https://github.com/example/test.git）が表示されること

#### 9. ConfigMap確認テスト

> kubectl get configmap hype-repos -o yaml
  * myapp のエントリが存在すること
  * url フィールドに正しいリポジトリURLが設定されていること
  * bound_at フィールドにタイムスタンプが設定されていること
  * updated_at フィールドにタイムスタンプが設定されていること

#### 10. リポジトリアンバインドテスト

> hype myapp repo unbind
  * アンバインド成功のメッセージが表示されること

#### 11. アンバインド後状態確認テスト

> hype myapp repo
  * "No repository bound" または類似のメッセージが表示されること

> kubectl get configmap hype-repos -o yaml
  * myapp のエントリが削除されていること、または空の状態であること

#### 12. エラーハンドリングテスト

> hype myapp repo unbind
  * 既にアンバインド状態でunbindを実行した場合のエラーメッセージが表示されること

> hype myapp repo update
  * バインドされていない状態でupdateを実行した場合のエラーメッセージが表示されること

#### 13. kubectl未インストール環境テスト

kubectl が利用できない環境では以下をテスト:

> hype myapp repo bind https://github.com/foontype/hype.git
  * 適切なエラーメッセージが表示されること
  * kubectl が必要であることが明示されること

### テスト後クリーンアップ

> kubectl delete configmap hype-repos --ignore-not-found=true
  * テスト用ConfigMapを削除
