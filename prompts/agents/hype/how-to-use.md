# Hype の使い方

Hype は Kubernetes AI デプロイメント用のモジュラー CLI ツールです。詳細な情報については [foontype/hype の README.md](https://github.com/foontype/hype) を参照してください。

## インストール

```bash
# クイックインストール
curl -sSL https://raw.githubusercontent.com/foontype/hype/main/install.sh | bash

# システム全体へのインストール（/usr/local/bin にインストール）
curl -sSL https://raw.githubusercontent.com/foontype/hype/main/install.sh | sudo bash

# 特定のバージョンをインストール
curl -sSL https://raw.githubusercontent.com/foontype/hype/main/install.sh | INSTALL_VERSION=v0.8.0 bash
```

## 基本的なコマンド

```bash
# デプロイメント用のデフォルトリソースを初期化
hype <hype-name> init

# デフォルトリソースのステータスをチェック
hype <hype-name> resources check

# レンダリングされた hype セクションテンプレートを表示
hype <hype-name> template

# 生成された設定で helmfile コマンドを実行
hype <hype-name> helmfile <helmfile-options>

# デフォルトリソースをクリーンアップ
hype <hype-name> deinit

# リポジトリバインディング操作
hype <hype-name> repo bind <repository-url>
hype <hype-name> repo unbind
hype <hype-name> repo info

# デプロイメントライフサイクルエイリアス
hype <hype-name> up        # ビルドとデプロイ（task build + helmfile apply）
hype <hype-name> down      # デプロイメントを破棄（helmfile destroy）
hype <hype-name> restart   # デプロイメントを再起動（down + up）

# バージョンとヘルプを表示
hype --version
hype --help
```

## 環境変数

- `HYPEFILE`: hypefile.yaml へのパス（デフォルト: hypefile.yaml）
- `DEBUG`: デバッグ出力を有効化（デフォルト: false）
- `HYPE_CACHE_DIR`: リポジトリデータをキャッシュするディレクトリ（デフォルト: ~/.hype/cache または .hype/）

## リポジトリバインディング

Hype は hype 名をリモート Git リポジトリにバインドすることをサポートしており、集中設定管理と再利用可能なデプロイメント設定を可能にします。

```bash
# リポジトリを hype 名にバインド（GitHub 省略記法）
hype my-nginx repo bind user/repo

# 完全な URL でリポジトリをバインド
hype my-nginx repo bind https://github.com/user/repo.git

# バインディング情報を表示
hype my-nginx repo info

# リポジトリバインディングを削除
hype my-nginx repo unbind

# リポジトリキャッシュを更新
hype my-nginx repo update
```

## hypefile.yaml の形式

`hypefile.yaml` ファイルは `---` で区切られた2つのセクションで構成されます：

1. **Hype セクション**: デフォルトリソース（ConfigMaps、Secrets）を定義
2. **Helmfile セクション**: 標準の Helmfile 設定

### hypefile.yaml の例

以下は nginx デプロイメントの例です：

```yaml
defaultResources:
  - name: "{{ .Hype.Name }}-nginx-state-values"
    type: StateValuesConfigmap
    values:
      nginx:
        replicaCount: 2
        image:
          tag: "1.21.6"
        service:
          type: ClusterIP
          port: 80
        ingress:
          enabled: true
          hosts:
            - host: "nginx-{{ .Hype.Name }}.example.com"
              paths:
                - path: /
                  pathType: Prefix
      hypeCurrentDirectoryValue: {{ .Hype.CurrentDirectory }}
      hypeNameValue: {{ .Hype.Name }}
      hypeTraitValue: {{ .Hype.Trait }}
      strValue: "This is a pen."
      numberValue: 12345
      boolValue: true

  - name: "{{ .Hype.Name }}-nginx-secrets"
    type: Secrets
    values:
      nginx: |
        auth:
          username: "admin"
          password: "changeme123"
      strValue: "This is a pen."
      numberValue: 12345
      boolValue: true

  - type: DefaultStateValues
    values:
      strValue: "This is apple."
      numberValue: 54321
      boolValue: false
      extraValue: "extra value"

expectedReleases:
  - "{{ .Hype.Name }}-nginx"

---
releases:
  - name: "{{ .StateValues.Hype.Name }}-nginx"
    namespace: default
    chart: bitnami/nginx
    version: "13.2.23"
    values:
      - autoHypeCurrentDirectory: {{ .StateValues.Hype.CurrentDirectory }}
        autoHypeName: {{ .StateValues.Hype.Name }}
        autoHypeTrait: {{ .StateValues.Hype.Trait }}
        hypeCurrentDirectoryValue: {{ .StateValues.hypeCurrentDirectoryValue }}
        hypeNameValue: {{ .StateValues.hypeNameValue }}
        hypeTraitValue: {{ .StateValues.hypeTraitValue }}
        strValue: {{ .StateValues.strValue }}
        numberValue: {{ .StateValues.numberValue }}
        boolValue: {{ .StateValues.boolValue }}
        extraValue: {{ .StateValues.extraValue }}

repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami

---
version: '3'

env:
  TASK_TEMP_DIR: .cache

tasks:
  build:
    desc: Build Container Images
    cmds:
      - echo "pass"

  push:
    desc: Push Container images
    cmds:
      - echo "pass"

  vars:
    desc: Hype Smoke Testing
    requires:
      vars: [HYPE_NAME, HYPE_TRAIT, HYPE_CURRENT_DIRECTORY]
    cmds:
      - |
        echo "HYPE_NAME=$HYPE_NAME"
        echo "HYPE_TRAIT=$HYPE_TRAIT"
        echo "HYPE_CURRENT_DIRECTORY=$HYPE_CURRENT_DIRECTORY"
        HYPE_LOG=false TRACE=false hype $HYPE_NAME template | yq eval -o json | jq .
```

## リソースタイプ

Hype は以下のデフォルトリソースタイプをサポートします：

### StateValuesConfigmap / Configmap
Helmfile テンプレートで状態値として使用できる Kubernetes ConfigMaps を作成します。

### Secrets
機密設定データ用の Kubernetes Secrets を作成します。

### DefaultStateValues
すべてのリリースで利用できるデフォルト状態値を定義します。

## 使用例

### カスタム設定で nginx をデプロイ

```bash
# my-nginx デプロイメント用のリソースを初期化
hype my-nginx init

# リソースのステータスをチェック
hype my-nginx resources check

# レンダリングされた設定を表示
hype my-nginx template

# デプロイメントを適用
hype my-nginx helmfile apply

# デプロイメントを更新
hype my-nginx helmfile diff
hype my-nginx helmfile apply

# クリーンアップ
hype my-nginx deinit
```

### リポジトリバインディングの使用

```bash
# リモート設定リポジトリにバインド
hype production repo bind company/k8s-configs

# バインドされたリポジトリ設定を使用してデプロイ
hype production init
hype production helmfile apply

# バインディングステータスをチェック
hype production repo info
```

### デバッグモード

```bash
DEBUG=true hype my-nginx init
```

## 依存関係

- Bash 4.0+
- Git（開発用）
- kubectl
- helmfile
- yq

詳細な情報と最新のドキュメントについては、[foontype/hype リポジトリ](https://github.com/foontype/hype)を参照してください。