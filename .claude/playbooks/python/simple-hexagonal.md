# Python Simple Hexagonal Architecture

## ディレクトリ構成

```
src/
├── index.py
├── libs/
├── app/
│   ├── models/
│   ├── services/
│   ├── gateways/
│   └── ...
├── domain/
│   ├── models/
│   ├── services/
│   ├── gateways/
│   └── ...
├── infrastructures/
│   └── ...
├── tests/
│   ├── unit/
│   ├── integration/
│   └── conftest.py
```

### レイヤー説明

**index.py**
- エントリーポイント

**libs**
- index.pyから参照するモジュール、サービスコンテナ、サービスプロバイダ、ログ、外部apiライブラリなどコード全体で使用する共通モジュール

**app**
- アプリケーションレイヤー

**domain**
- ドメインレイヤー

**infrastructures**
- インフラレイヤー

### 各レイヤー内の構成

**models**
- エンティティ、値オブジェクト、列挙型
- レイヤー実装は models に実装します

**services**
- データを持たない処理モデル services に実装します

**gateways**
- リポジトリ、外部api呼び出しなどのインターフェイスを実装します。実装はインフラレイヤーに実装します

## Python コーディングスタイル

- **型ヒント**: Python 3.12+スタイル必須（pyright + PEP 695）
- **Docstring**: NumPy形式
- **命名**: クラス(PascalCase)、関数(snake_case)、定数(UPPER_SNAKE)、プライベート(_prefix)

## テスト戦略（TDD）

t-wada流のテスト駆動開発（TDD）を徹底

### サイクル
🔴 Red » 🟢 Green » 🔵 Refactor

### 手順
1. TODO作成
2. 失敗テスト
3. 最小実装（仮実装OK）
4. リファクタ

### 原則
- 小さなステップで進める
- 三角測量で一般化
- 不安な部分から着手
- テストリストを常に更新

### 三角測量の例

1. **仮実装**: `return 5`
   ```python
   assert add(2, 3) == 5
   ```

2. **一般化**: `return a + b`
   ```python
   assert add(10, 20) == 30
   ```

3. **エッジケース確認**
   ```python
   assert add(-1, -2) == -3
   ```

### 注意点
- 1test::1behavior
- Red»Greenでコミット
- 日本語テスト名推奨
- リファクタ: 重複|可読性|SOLID違反時

### テスト種別
- **単体**: 基本動作 `tests/unit/`
- **プロパティ**: Hypothesis自動生成 `tests/property/`
- **統合**: 連携テスト `tests/integration/`
- **テスト命名**: `test_[正常系|異常系|エッジケース]_条件で結果()`