# Claude Code Remote Control on k3s

Claude Code を Remote Control サーバーモードで動かすための Pod 定義です。
claude.ai/code・Claude モバイルアプリ・VS Code 拡張から接続してこの Pod 上で作業します。

## 仕組み

- Remote Control は **outbound HTTPS のみ**（Anthropic API へのポーリング）。Service/Ingress 不要
- 要 claude.ai サブスクリプション（Pro/Max/Team/Enterprise）。API キー/OAuth トークンは**非対応**
- 認証は `/login` による OAuth のみ。初回のみ対話的ログインが必要
- 参考: https://code.claude.com/docs/en/remote-control

## ファイル構成

```
apps/claude-remote/
├── Dockerfile          # Node.js + claude CLI
├── entrypoint.sh       # 初回ログイン未済ならスリープして指示を出す
├── claude-remote.yaml  # Namespace, PVC x2, Deployment
└── README.md

argocd/applications/
└── claude-remote.yaml  # ArgoCD Application
```

## セットアップ

### 1. nerdctl をインストール

k3s の containerd を直接叩いてビルドするので、docker は不要です。
`nerdctl-full` バンドルに buildkit も同梱されています。

```bash
# nerdctl + buildkit + runc など一式を /usr/local に展開
curl -sL https://github.com/containerd/nerdctl/releases/download/v2.2.2/nerdctl-full-2.2.2-linux-amd64.tar.gz \
  | sudo tar xz -C /usr/local

# buildkit デーモンを起動（ビルドに必要）
sudo systemctl enable --now buildkit
```

既にインストール済みならスキップ。

### 2. イメージをビルド

```bash
cd apps/claude-remote
sudo nerdctl --namespace k8s.io build -t claude-remote:local .
```

`--namespace k8s.io` を指定することで、k3s が使う containerd namespace に
直接イメージが登録されます。`docker save` / `k3s ctr images import` のような
中間ステップは不要です。

確認：

```bash
sudo k3s ctr images ls | grep claude-remote
```

マニフェストは `imagePullPolicy: Never` になっているので、レジストリへは
取りに行きません。マルチノード構成の場合は、Pod がスケジュールされうる全ノードで
ビルドを実行する必要があります（または 1 ノードで `nerdctl save` → 他ノードで
`nerdctl load`）。

イメージを更新したいときは、同じ `nerdctl build` を再実行してから
`kubectl rollout restart -n claude-remote deploy/claude-remote` します。

### 3. デプロイ

```bash
# ArgoCD 経由
kubectl apply -f argocd/applications/claude-remote.yaml

# もしくは手動
kubectl apply -f apps/claude-remote/claude-remote.yaml
```

### 4. 初回ログイン

デプロイ直後は未認証なので Pod は `sleep infinity` で待機します。

```bash
# Pod に入る
kubectl exec -it -n claude-remote deploy/claude-remote -- bash

# claude を起動して /login
claude
> /login
# → 表示される URL をブラウザで開いて OAuth 完了

# exit して Pod を再起動
exit
kubectl rollout restart -n claude-remote deploy/claude-remote
```

認証情報は `claude-config` PVC に永続化されるので、以降は自動で
`claude remote-control` が起動します。

### 5. セッションに接続

Pod のログからセッション URL を取得：

```bash
kubectl logs -n claude-remote deploy/claude-remote -f
```

- URL をブラウザで開く → claude.ai/code でセッションが出る
- Claude モバイルアプリや VS Code 拡張からも同じセッションが一覧に表示される

## ワークスペースにリポジトリを置く

`/workspace` は `claude-workspace` PVC（20Gi）にマウントされています。

```bash
kubectl exec -it -n claude-remote deploy/claude-remote -- bash
cd /workspace
git clone https://github.com/yox2yox/some-repo.git
```

## カスタマイズ

### 並行セッション（git worktree）

同一リポジトリで複数セッションを並行で走らせたい場合は、
`claude-remote.yaml` の Deployment の args を書き換えてください：

```yaml
command: ["claude", "remote-control"]
args: ["--spawn", "worktree", "--capacity", "8"]
```

※ `/workspace` が git リポジトリである必要があります。

### サンドボックス

ホストからより強く隔離したい場合は `--sandbox` を付けます（ファイルシステム・
ネットワークを制限、デフォルト off）：

```yaml
args: ["--spawn", "same-dir", "--sandbox"]
```

### ストレージサイズ

`claude-remote.yaml` の PVC `claude-workspace` の `storage: 20Gi` を調整してください。

## トラブルシューティング

### Pod が crashloop / セッションが立ち上がらない

```bash
kubectl logs -n claude-remote deploy/claude-remote --tail=100
```

- 「Remote Control requires a claude.ai subscription」→ OAuth 未ログイン。手順3をやり直し
- 「Remote Control requires a full-scope login token」→ `CLAUDE_CODE_OAUTH_TOKEN` のような
  inference-only トークンが使われている。`unset` してから `/login`

### 10 分以上ネットワーク切断で Pod のプロセスが終了する

Claude Code の仕様。k3s が自動で再起動するので通常は問題なし。
頻発する場合はノードのネットワーク安定性を確認。

### CLI バージョンを上げたい

Dockerfile の `@anthropic-ai/claude-code@latest` を特定バージョンに固定 or 再ビルドして
`kubectl rollout restart` で反映。Remote Control は v2.1.51 以降必須。

### ErrImageNeverPull になる

`imagePullPolicy: Never` なのにイメージが見つからない場合、ビルド時に
`--namespace k8s.io` を指定し忘れている可能性があります。

```bash
# k3s 用の namespace にあるか確認
sudo k3s ctr images ls | grep claude-remote

# 出てこなければ再ビルド
sudo nerdctl --namespace k8s.io build -t claude-remote:local apps/claude-remote/
```

マルチノードの場合は、Pod がスケジュールされたノードにイメージが無い可能性も。

```bash
kubectl get pod -n claude-remote -o wide  # 配置ノード確認
```
