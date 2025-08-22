# hype cli の実装

hype cli は ai の kubernetes デプロイを支援する helmfile ラッパーツールです。

hypefile.yaml の設定読み込んで、デフォルトリソースの作成と、helmfile によるコンテナデプロイを行います。

## hypefile.yaml フォーマット

.claude/hypefile.yaml 参照。

defaultResources には次のタイプがあります。

StateValueConfigmap = hype <hype name> init 時、name の名前、values の内容で kubernetes コンフィグマップリソースが作成されます。コンフィグマップの内容は hype <hype name> helmfile 時に --state-value-file オプションでファイルとして渡されます。

ConfigMap = hype <hype name> init 時、name の名前、values の内容で kubernetes コンフィグマップリソースが作成されます。

Secrets = hype <hype name> init 時、name の名前、values の内容で kubernetes シークレットリソースが作成されます。

```
usage:

hype <hype name> init
  デフォルトリソース作成を行います。
  
hype <hype name> helmfile <helmfile options>
  helmfile コマンド実行します
  StateValueConfigmap が示すコンフィグマップ設定が --state-value-file で helmfile コマンドに渡されます。
  また、<hype name> が -e オプションとして helmfile コマンドに渡されます。

```

## 例

```
hype my-nginx helmfile apply
  my-nginx という環境名で hypefile.yaml の helmfile 設定を適用する
  hypefile.yaml に書かれたデフォルトリソースが事前に展開され、環境名は my-nginx。

```

TODO

