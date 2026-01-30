# ArgoCD Applications

Individual ArgoCD Application manifests for deploying components.

## Deployment Order (Sync Waves)

| Wave | Application | Purpose |
|------|-------------|---------|
| 0 | cert-manager | SSL certificate management |
| 1 | ingress-nginx | Load balancer & traffic routing |
| 2 | oauth2-proxy | GitHub authentication |
| 3 | webapp | Main application |

## Usage

```bash
# Deploy all applications
kubectl apply -f argocd/apps/

# Deploy individually
kubectl apply -f argocd/apps/cert-manager.yaml
```

## Prerequisites

Before deploying, ensure:
1. ArgoCD is installed in the cluster
2. helm-secrets is configured (see `argocd/config/`)
3. Secrets are encrypted with SOPS/age

