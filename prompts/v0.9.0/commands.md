# HYPE CLI Commands

hype CLI は、リポジトリの構成起動方法を定義する hype.yaml を読み込み、task と helm コマンドを使用してコンテナイメージのビルドと kubenetes を起動します。

## hype.yaml 例

```
helm:
  chartPath: relative/path/to/helmChart

task:
  taskfilePath: relative/path/to/Taskfile.yaml

depends:
  - name: depend-name
  TODO

addons:
  - name: addon-name
  TODO

resources:
  - 
  TODO
```

|設定|説明
|-|-|
|helm.chartPath|Helmチャートへのパス。この hype.yaml からの相対パス。|
|task.taskfilePath|Taskfile へのパス。この hype.yaml からの相対パス。|

## 基本オプション

```bash
hype
  -f
    <hype path>
  --file
    <hype path>
```

## 構成操作
```bash
hype
  install
    <release name>
  uninstall
    <release name>
  upgrade
    <release name>
  status
    <release name>
```

## リポジトリバインド操作
```bash
hype
  bind
    list
    get
      <release name pattern>
    set
      <release name pattern>
    unset
      <release name pattern>
```

## スキーマ管理
```bash
hype
  schema
    list
    file
      <schema file path>
    configmap
      <schema config map name>
    secrets
      <schema secrets name>
```

## 検証 (validate)
```bash
hype
  validate
    file
      <file path>
        [--schema <schema file path>]
    configmap
      <config map name>
        [--schema <schema config map name>]
    secrets
      <secrets name> 
        [--schema <schema secrets name>]
```

## 読み込み (read)
```bash
hype
  read
    file
      <file path>
        [--schema <schema file path>]
    configmap
      <config map name>
        [--schema <schema config map name>]
    secrets
      <secrets name>
        [--schema <schema secrets name>]
```

## 書き込み (write)
```bash
hype
  write
    file
      <file path>
        [--schema <schema file path>]
    configmap
      <config map name>
        [--schema <schema config map name>]
    secrets
      <secrets name> 
        [--schema <schema secrets name>]
```