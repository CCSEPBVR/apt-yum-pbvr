# APTリポジトリ更新（保守者向け）

## 必要なパッケージ

WSL Ubuntu 20.04で次のコマンドが必要です。

- `dpkg-dev`（`dpkg-scanpackages`）
- `apt-utils`（`apt-ftparchive`）
- `gzip`（`gzip -n`）

不足している場合は、保守者の判断でパッケージを用意してから実行してください。更新スクリプトはパッケージを自動インストールしません。

## 実行方法

リポジトリのルートで、公開するPBVRのdebを1つ指定します。

```sh
./scripts/update-apt-repository.sh /path/to/pbvr_<version>_amd64.deb
```

スクリプトはdebのメタデータを検証し、`Package: pbvr`、`Architecture: amd64`、空でない`Version`を満たす場合だけ、正規のファイル名で次の場所に公開します。

```text
apt/pool/main/p/pbvr/pbvr_<version>_amd64.deb
```

`pool/main/p/pbvr/`には常に最新の1バージョンだけが残ります。`Packages`、`Packages.gz`、`Release`は一時ディレクトリで生成・検証してからAPT配下を置き換えるため、生成や検証に失敗した場合は既存のAPTリポジトリを変更しません。リポジトリは署名せず、`InRelease`と`Release.gpg`も作成しません。

YUM配下やAPT以外のファイルはこのスクリプトでは変更しません。PBVR本体のインストールや実行も行いません。
