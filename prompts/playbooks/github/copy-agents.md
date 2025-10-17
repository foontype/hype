# Agent Tomes Copy Guide

## Overview
指定リポジトリから agents の複製を依頼された場合の処理手順を説明します。

## Process
指定リポジトリから agents の複製を依頼された場合は、以下の手順で実行してください：

1. **指定リポジトリの prompts/playbooks をコピー**
2. **現在のワーキングコピーの prompts/playbooks にディレクトリごと入れ替えで配置**

## Implementation Steps
1. 指定リポジトリから `prompts/playbooks` ディレクトリの内容を取得
2. 現在の `prompts/playbooks` ディレクトリを削除
3. 取得した内容を新しい `prompts/playbooks` ディレクトリとして配置

## Important Notes
- 完全な入れ替え操作です（既存の内容は上書きされます）
- ディレクトリ構造ごとコピーしてください
- 権限設定も適切に維持してください