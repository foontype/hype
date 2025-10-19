# .claude/skills Workflow Guide

## Copy .claude/skills

### Overview
指定リポジトリから skills の複製を依頼された場合の処理手順を説明します。

### Process
指定リポジトリから skills の複製を依頼された場合は、以下の手順で実行してください：

1. **指定リポジトリの .claude/skills をコピー**
2. **現在のワーキングコピーの .claude/skills にディレクトリごと入れ替えで配置**

### Implementation Steps
1. 指定リポジトリから `.claude/skills` ディレクトリの内容を取得
2. 現在の `.claude/skills` ディレクトリを削除
3. 取得した内容を新しい `.claude/skills` ディレクトリとして配置

### Important Notes
- 完全な入れ替え操作です（既存の内容は上書きされます）
- ディレクトリ構造ごとコピーしてください
- 権限設定も適切に維持してください

## Learning new skills
スキルの学習を依頼された場合は、依頼内容を調査して、学習結果を prompts ディレクトリにまとめて、.claude/skills からリンクを作成してください。

### Learning Steps
1. 学んだ内容を prompts/playbooks/<category>/<skill name>.md に保存する
   ```
   例) python の layered architecture を学習した場合は、prompts/playbooks/python/layered-architecture.md に、学習内容をまとめる。
   ```
2. .claude/skills/<category>-<skill name>/SKILL.md から "@" インポートで参照を追加する
   ```
   例) prompts/playbooks/python/layered-architecture.md の場合、.claude/skills/python-layered-architecture/SKILL.md からリンクを張る。
   ---
   name: Name of this learning document
   description: Description of this learning document
   ---
   
   @prompts/playbooks/python/layered-architecture.md
   
   ```
