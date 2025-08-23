# hype cli の実装

hype cli は ai の kubernetes デプロイを支援する helmfile ラッパーツールです。

hypefile.yaml の設定読み込んで、デフォルトリソースの作成と、helmfile によるコンテナデプロイを行います。

実装言語は bash で src/hype に実装します。

各関数のテストは tests ディレクトリに bats ファイルを書いてください。

## hypefile.yaml フォーマット

.claude/hypefile.yaml 参照。

### hypefile.yaml の処理方法

ファイルセパレーター "---" で hype セクションと helmfile セクションに分離されます。

hype が起動すると、ファイルセパレーターで二つの一時ファイルを生成します。

hype セクションファイルは、init または deinit サブコマンド時に処理します。

{{ .Hype.Name }} を <hype name> に置換してください。その後、hype セクションに書かれたデフォルトリソースを作成または破棄します。

デフォルトリソースの種類のついては defaultResources の項を参照してください。

helmfile セクションは、 helmfile サブコマンド時に処理します。これは、そのまま helmfile -f にパスします。

### defaultResources

defaultResources には次のタイプがあります。

StateValueConfigmap = hype <hype name> init 時、name の名前、values の内容で kubernetes コンフィグマップリソースが作成されます。コンフィグマップの内容は hype <hype name> helmfile 時に --state-value-file オプションでファイルとして渡されます。

ConfigMap = hype <hype name> init 時、name の名前、values の内容で kubernetes コンフィグマップリソースが作成されます。

Secrets = hype <hype name> init 時、name の名前、values の内容で kubernetes シークレットリソースが作成されます。

hypefile.yaml の {{ .Hype.Name }} は <hype name> で展開されます。

## コマンドの使い方

```
usage:

hype <hype name> init
  デフォルトリソース作成を行います。
  作成済なら何もしません。

hype <hype name> deinit
  デフォルトリソースの破棄を行います。

hype <hype name> resources
  デフォルトリソース一覧を表示します。
  リソースが作成済みかそうでないかを表示します。
  
hype <hype name> helmfile <helmfile options>
  helmfile コマンド実行します
  StateValueConfigmap が示すコンフィグマップ設定が --state-value-file で helmfile コマンドに渡されます。
  また、<hype name> が -e オプションとして helmfile コマンドに渡されます。

```

### コマンド例

```
hype my-nginx helmfile apply
  my-nginx という環境名で hypefile.yaml の helmfile 設定を適用する
  hypefile.yaml に書かれたデフォルトリソースが事前に展開され、環境名は my-nginx。

```

