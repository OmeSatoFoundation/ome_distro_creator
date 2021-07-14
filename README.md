# IT未来塾 Raspberry Pi 用 ディストリビューションクリエーター
## 概要
IT未来塾で使用するための Raspberry Pi 用 ディストリビューションを作成します。

- ベースイメージ (raspian) をダウンロード
- 教材ファイルと依存パッケージをインストール
- ファイルシステム/パーティションの切り詰め・圧縮

## 使い方

```sh
# `install.sh` がadaptive.u-aizu.ac.jp/gitlab より教材を ssh プロトコルでダウンロードするため、途中 (設定している人は) 秘密鍵のパスワードを入力する必要がないように `ssh-agent` セッションを生成する。
# 秘密鍵にパスワードを生成していない人は飛ばしてよい。
$ eval $(ssh-agent -s)
$ ssh-add ~/.ssh/id_rsa # 秘密鍵への path は適当なものに変更すること
### 設定されていればパスワードを入力 ###

# イメージアーカイブ作成
$ sudo SSH_AUTH_SOCK=$SSH_AUTH_SOCK SSH_AGENT_PID=$SSH_AGENT_PID ./install.sh
```
