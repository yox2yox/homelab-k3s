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

### 1. イメージをビルドして k3s に import

レジストリにはプッシュせず、ビルドしたイメージを直接 k3s の containerd に
読み込ませます。

```bash
cd apps/claude-remote
docker build -t claude-remote:local .
docker save claude-remote:local -o /tmp/claude-remote.tar
sudo k3s ctr images import /tmp/claude-remote.tar
rm /tmp/claude-remote.tar
```

マニフェストは `imagePullPolicy: Never` でレジストリへ取りに行かない設定に
なっています。マルチノード構成の場合は、Pod がスケジュールされうる全ノードで
上記の import を実行する必要があります。

イメージを更新したいときは、同じ手順でビルド → import してから
`kubectl rollout restart -n claude-remote deploy/claude-remote` します。

### 2. デプロイ

```bash
# ArgoCD 経由
kubectl apply -f argocd/applications/claude-remote.yaml

# もしくは手動
kubectl apply -f apps/claude-remote/claude-remote.yaml
```

### 3. 初回ログイン

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

### 4. セッションに接続

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

Dockerfile の `@anthropic-ai/claude-code@latest` を特定バージョンに固定 or 再ビルド後、
手順1の import を再実行して `kubectl rollout restart` で反映。
Remote Control は v2.1.51 以降必須。

### ImagePullBackOff になる

`imagePullPolicy: Never` なのに `ErrImageNeverPull` が出る場合、
Pod がスケジュールされたノードにイメージが import されていません。

```bash
# どのノードに居るか確認
kubectl get pod -n claude-remote -o wide

# そのノードで import を実行
sudo k3s ctr images ls | grep claude-remote
```
