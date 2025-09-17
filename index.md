---
title: Home
layout: default
---

# package manager
## apt
以下のコマンドでレポジトリを追加する
```
echo "deb [arch=amd64 trusted=yes] https://ccsepbvr.github.io/apt-yum-pbvr/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/pbvr.list
```

以下のコマンドでインストールできるようになる
```
sudo apt update
sudo apt install pbvr
```

## yum
`/etc/yum.repos.d/pbvr.repo`を作成する<br>
以下の記述を追加する
```
[pbvr-repo]
name=pbvr
baseurl=https://ccsepbvr.github.io/apt-yum-pbvr/yum
enabled=1
gpgcheck=0
```

以下のコマンドでインストールできるようになる
```
sudo yum clean all
sudo yum makecache
sudo yum install pbvr
```