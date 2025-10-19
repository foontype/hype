
# HYPE CLI Commands

## コマンドツリー

```yaml
# (description) キー
#   コマンドの仕様説明です。
# (optional) キー
#   これより下位の階層は、オプション引数であることを示しています。
hype:
  install:
    <release name>:
      (description):
        - hype.yaml に書かれた helm chart を <release name> として helm install を実行する
  uninstall:
    <release name>:
      (descripton): hype.yaml に書かれた helm chart を <release name> として helm uninstall を実行する
  upgrade:
    <release name>:
      (descripton): hype.yaml に書かれた helm chart を <release name> として helm upgrade を実行する
  status:
    <release name>:
      (descripton): hype.yaml に書かれた helm chart を <release name> として helm status を実行する
  bind:
    list:
      (description): バインド一覧を表示
    get:
      <release name pattern>:
        (description):
          - <release name pattern> にバインドされたリポジトリ、ブランチ、機能フィルタを表示
          - 存在しない場合は、exitcode 1 を設定
    set:
      <release name pattern>:
        (descriptoin):
          - リリース名に対して、事前設定をセットする
          - 設定は kubernets configmap に保存する
          - hype install, uninstall, upgrade でリリース名がパターンに一致する場合、リモートリポジトリやブランチ、機能フィルタ、helm options を適用してから処理を行うようになる
        (optional):
          --repository:
            <repository url>:
              (description): リリース名に対応するリポジトリ名を指定
              (optional):
                --branch:
                  (description): リポジトリに対するブランチ、またはタグを指定
                --path:
                  (description): リポジトリに対する hype.yaml への相対パスを指定
            none:
              (description): バインドのリポジトリ設定を解除
          --only:
            (description): 機能フィルタを指定
            addons:
              (description): このリリースをインストールせず、アドオンのみインストールするように設定。デバッグ用。
            depends:
              (description): このリリースをインストールせず、依存関係のみンストールするように設定。デバッグ用。
            release:
              (description): このリリースをインストールして、アドオンと依存関係をインストールしないように設定。デバッグ用。
            all:
              (description): 全てインストールするように、設定をリセット。
          --install:
            <release name>:
              (description): bind と同時に、リリース名をインストールする。ただし、<release name> が <release name pattern> に一致しない場合はエラー。
          --:
            <helm options>:
              (description): "--" 移行は helm install や upgrade の際に引き渡す helm コマンドのオプションとして、バインド設定の configmap に保存する。
    unset:
      <release name pattern>:
        (description):
          <release name pattern> のバインド設定を削除する。
  resource:
    schema:
      list:
        (description): hype.yaml の schemaPath に格納されているスキーマリストを表示する。
      file:
        <schema file path>:
          (description):
            - schemaPath からの相対パス <schemaPath>/file/<schema file path>.schema.json に存在するスキーマを表示する。
            - 例) <scehma file name> に data/my_data.yaml が指定された場合、<schemaPath>/file/data/my_data.yaml.schema.json
      configmap:
        <schema configmap name>:
          (description):
            - schemaPath からの相対パス <schemaPath>/configmap/<schema configmap name>.schema.json に存在するスキーマを表示する。
            - 例) <schema configmap name> に my_configmap が指定された場合 <schemaPath>/configmap/my_configmap.yaml.schema.json
      secrets:
        <schema secrets name>:
          (description):
            - schemaPath からの相対パス <schemaPath>/secrets/<schema secrets name>.schema.json に存在するスキーマを表示する。
            - 例) <scehma secrets name> に my_secrets が指定された場合 <schemaPath>/secrets/my_secrets.yaml.schema.json
    validate:
      file:
        <file path>:
          (description): <file path> を hype resource schema file <file path> で得られるスキーマで検証する。
          (opional):
            --schema:
              <schema file path>: <file path> から特定されるスキーマの代わりに <schemaPath>/<schema file path> で得られるスキーマで検証する
      configmap:
        <configmap name>:
          (description): <configmap name> を hype resource schema configmap <configmap name> で得られるスキーマで検証する。
          (optional):
            --schema:
              <schema configmap name>: <schema configmap name> から特定されるスキーマの代わりに <schemaPath>/<schema file path> で得られるスキーマで検証する
      secrets:
        <secrets name>:
          (description): <secrest name> を hype resource schema secrets <secrets name> で得られるスキーマで検証する。
          (optional):
            --schema:
              <schema secrets name>: <schema configmap name> から特定されるスキーマの代わりに <schemaPath>/<schema file path> で得られるスキーマで検証する
    read:
      file:
        <file path>:
          (description): <file path> の内容を表示する。ただし、hype resource schema file <file path> で得られるスキーマで検証に失敗した場合はエラー。
          (opional):
            --schema:
              <schema file path>: <file path> から特定されるスキーマの代わりに <schemaPath>/<schema file path> で得られるスキーマで検証する
      configmap:
        <configmap name>:
          (description): <configmap name> の内容を表示する。ただし、hype resource schema configmap <configmap name> で得られるスキーマで検証が失敗した場合はエラー。
          (optional):
            --schema:
              <schema configmap name>: <schema configmap name> から特定されるスキーマの代わりに <schemaPath>/<schema file path> で得られるスキーマで検証する
      secrets:
        <secrets name>:
          (description): <secrest name> の内容を表示する。ただし、hype resource schema secrets <secrets name> で得られるスキーマで検証に失敗した場合は、エラー。
          (optional):
            --schema:
              <schema secrets name>: <schema configmap name> から特定されるスキーマの代わりに <schemaPath>/<schema file path> で得られるスキーマで検証する
    write:
      file:
        <file path>:
          (description): hype resource schema file <file path> で得られるスキーマの内容で、<file path>にファイルを作成。
          (opional):
            --schema:
              <schema file path>: <file path> から特定されるスキーマの代わりに <schemaPath>/<schema file path> で得られるスキーマを使用する
      configmap:
        <configmap name>:
          (description): hype resource schema configmap <configmap name> で得られるスキーマの内容で configmap <configmap name> を作成する。
          (optional):
            --schema:
              <schema configmap name>: <schema configmap name> から特定されるスキーマの代わりに <schemaPath>/<schema file path> で得られるスキーマを使用する
      secrets:
        <secrets name>:
          (description): hype resource schema secrets <secrets name> のスキーマの内容で secrest <secrets name> を作成する。
          (optional):
            --schema:
              <schema secrets name>: <schema configmap name> から特定されるスキーマの代わりに <schemaPath>/<schema file path> で得られるスキーマを使用する。
```

