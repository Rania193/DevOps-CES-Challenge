# ArgoCD Configuration

Configuration files for ArgoCD itself (not the deployed applications).

## Files

| File | Purpose |
|------|---------|
| `argocd-github-oauth.yaml` | GitHub OAuth login for ArgoCD UI |
| `argocd-repo-server-patch.yaml` | Patch to enable helm-secrets plugin |
| `argocd-ingress.yaml` | Ingress for external access with TLS |
| `argocd-cmd-params-cm.yaml` | Server config for ingress mode |

## Applying Configuration

Apply all config files (except the patch file):
```bash
kubectl apply -f argocd/config/argocd-cmd-params-cm.yaml
kubectl apply -f argocd/config/argocd-github-oauth.yaml
kubectl apply -f argocd/config/argocd-ingress.yaml
```

Apply the repo-server patch separately:
```bash
kubectl patch deployment argocd-repo-server -n argocd \
  --patch-file argocd/config/argocd-repo-server-patch.yaml
```

## Access Modes

### Option 1: Port-Forward (Simple)
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access: https://localhost:8080
```

### Option 2: Ingress with TLS (Production)
```bash
kubectl apply -f argocd/config/argocd-cmd-params-cm.yaml
kubectl apply -f argocd/config/argocd-ingress.yaml
kubectl -n argocd rollout restart deployment argocd-server
# Access: https://datavisyn-argocd.duckdns.org
```

## Setup

See [README.md](../../README.md) for detailed setup instructions.

