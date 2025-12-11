# Jellyfin on k3s with ArgoCD

このディレクトリには、k3s上でArgoCDを使用してJellyfinを運用するための設定ファイルが含まれています。

## ファイル構成

```
apps/jellyfin/
├── jellyfin.yaml   # メインマニフェスト（Namespace, PVC, Deployment, Service）
├── ingress.yaml    # Ingress設定
└── README.md       # このファイル

argocd/applications/
└── jellyfin.yaml   # ArgoCD Application定義
```

## デプロイ前の設定

### 1. ArgoCD Application定義の編集

`argocd/applications/jellyfin.yaml` を編集して、実際のGitリポジトリURLに変更してください：

```yaml
spec:
  source:
    repoURL: https://github.com/your-username/homelab-k3s.git  # ← 実際のURLに変更
```

### 2. Ingress設定の編集

`apps/jellyfin/ingress.yaml` を編集して、実際のドメイン名に変更してください：

```yaml
spec:
  rules:
  - host: jellyfin.example.com  # ← 実際のドメインに変更
```

### 3. ストレージの確認

`apps/jellyfin/jellyfin.yaml` のPersistentVolumeClaimを確認し、必要に応じてストレージサイズを調整してください：

- `jellyfin-config`: Jellyfinの設定データ（デフォルト: 10Gi）
- `jellyfin-media`: メディアファイル（デフォルト: 100Gi）

## デプロイ方法

### ArgoCD経由でデプロイ

```bash
# ArgoCD Applicationを作成
kubectl apply -f argocd/applications/jellyfin.yaml

# 同期状態の確認
kubectl get application jellyfin -n argocd

# ArgoCD UIで確認
# http://argocd.example.com
```

### 手動デプロイ（テスト用）

```bash
# マニフェストを直接適用
kubectl apply -f apps/jellyfin/jellyfin.yaml
kubectl apply -f apps/jellyfin/ingress.yaml

# デプロイ状態の確認
kubectl get pods -n jellyfin
kubectl get svc -n jellyfin
kubectl get ingress -n jellyfin
```

## アクセス方法

### Ingress経由

設定したドメインでアクセス：
- http://jellyfin.example.com （HTTPの場合）
- https://jellyfin.example.com （TLS設定した場合）

### ポートフォワード経由（テスト用）

```bash
kubectl port-forward -n jellyfin svc/jellyfin 8096:8096
```

その後、ブラウザで http://localhost:8096 にアクセス

## 初期設定

1. ブラウザでJellyfinにアクセス
2. 初回セットアップウィザードに従って設定
3. 管理者アカウントを作成
4. メディアライブラリを設定（`/media` ディレクトリを指定）

## メディアファイルの追加

メディアファイルをPVCに追加する方法：

```bash
# Jellyfinポッドの名前を取得
POD_NAME=$(kubectl get pods -n jellyfin -l app=jellyfin -o jsonpath='{.items[0].metadata.name}')

# ローカルからファイルをコピー
kubectl cp /path/to/your/media $POD_NAME:/media -n jellyfin
```

または、NFSやCIFSなどの共有ストレージをマウントすることも可能です。

## トラブルシューティング

### ポッドが起動しない場合

```bash
# ログを確認
kubectl logs -n jellyfin -l app=jellyfin

# イベントを確認
kubectl describe pod -n jellyfin -l app=jellyfin
```

### PVCがバインドされない場合

```bash
# PVCの状態を確認
kubectl get pvc -n jellyfin

# ストレージクラスを確認
kubectl get storageclass
```

k3sのデフォルトストレージクラス（local-path）を使用している場合、自動的にPVがプロビジョニングされます。

## カスタマイズ

### ハードウェアアクセラレーション

GPUを使用したハードウェアアクセラレーションを有効にする場合は、`jellyfin.yaml`のDeploymentに以下を追加：

```yaml
spec:
  template:
    spec:
      containers:
      - name: jellyfin
        securityContext:
          privileged: true
        volumeMounts:
        - name: dri
          mountPath: /dev/dri
      volumes:
      - name: dri
        hostPath:
          path: /dev/dri
```

### リソース制限の調整

負荷に応じて、`resources`セクションを調整してください：

```yaml
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi
```

## 参考リンク

- [Jellyfin公式ドキュメント](https://jellyfin.org/docs/)
- [Jellyfin Docker Hub](https://hub.docker.com/r/jellyfin/jellyfin)
- [ArgoCD公式ドキュメント](https://argo-cd.readthedocs.io/)
