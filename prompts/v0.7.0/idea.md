
* hype <hype name> use repo <repository>
  hype名にリポジトリを紐付けする
  configmap に自分を登録するとともにリポジトリを対にして記録 
  この hype名にリポジトリが紐づいている場合は、
  一時領域のリポジトリのワーキングコピーに cd して hype を実行
  紐づいていない場合は、カレントディレクトリで hype を実行

* hype <hype name> unuse
  リポジトリへの紐付けを解除

* hype update
  紐づいているリポジトリを
  全て一時領域にチェックアウト
  存在するリポジトリは git pull

* hype list
  hype名一覧と各hypeに紐付いているリポジトリを表示
  リポジトリが紐づいていない場合は .
