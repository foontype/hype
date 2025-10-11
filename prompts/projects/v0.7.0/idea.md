```
- hype
  - <hype name>
    - [未指定時]
      - hypefile の description を表示する
    - repo
      - bind
        - <repository url> [--branch <branch name>] [--path <path>]
        - <hype name> に <repo name> を紐付けます
        - 紐づけると configmap hype-repos にハイプ名とリポジトリ URL、ブランチ名、パスを記録します
        - 紐づけられた hype <hype name> への操作を行う際、configmap から紐付けを探し、
          repository url のブランチ <branch name> を $HYPE_CACHE_DIR/repo/<hype name> にチェックアウトして
          そこに cd してから実行するようになります
        - git submodule update --init も実行されます
        - path が指定されている場合は、さらにそのパスに cd します
        - bind されていない場合はカレントディレクトリを使用します
      - unbind
        - <hype name> の <repo name> の紐付けを外します
      - update
        - リポジトリと紐付けされている場合、キャッシュを更新します
        - キャッシュを削除し、チェックアウトし直します
      - [未指定時]
        - bind した url を表示する
        - bind されていればその url にある hypefile の description を表示する
        - bind されていなければその旨を表示
```
