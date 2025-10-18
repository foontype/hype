# HYPE CLI Commands

## 基本操作
```bash
hype install <release name>
hype uninstall <release name>
hype upgrade <release name>
hype status <release name>
```

## 設定操作
```bash
hype bind
hype list
hype get <release name pattern>
hype set <release name pattern>
hype unset <release name pattern>
```

## スキーマ管理
```bash
hype schema list
hype schema file <schema file path>
hype schema configmap <schema config map name>
hype schema secrets <schema secrets name>
```

## 検証 (validate)
```bash
hype validate file <file path> [optional] --schema <schema file path>
hype validate configmap <config map name> [optional] --schema <schema config map name>
hype validate secrets <secrets name> [optional] --schema <schema secrets name>
```

## 読み込み (read)
```bash
hype read file <file path> [optional] --schema <schema file path>
hype read configmap <config map name> [optional] --schema <schema config map name>
hype read secrets <secrets name> [optional] --schema <schema secrets name>
```

## 書き込み (write)
```bash
hype write file <file path> [optional] --schema <schema file path>
hype write configmap <config map name> [optional] --schema <schema config map name>
hype write secrets <secrets name> [optional] --schema <schema secrets name>
```