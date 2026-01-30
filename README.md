# Datavisyn DevOps Challenge

Kubernetes deployment on AWS EKS with OAuth2 authentication (GitHub), secrets management (helm-secrets + SOPS), and GitOps (ArgoCD).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS EKS                                │
│                                                                 │
│  ┌──────────┐    ┌──────────────┐    ┌───────────────────────┐ │
│  │ Ingress  │───►│ OAuth2-Proxy │───►│ FastAPI App (webapp)  │ │
│  │  (NLB)   │    │  (GitHub)    │    │                       │ │
│  └──────────┘    └──────────────┘    └───────────────────────┘ │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐│
│  │ ArgoCD + helm-secrets - GitOps with encrypted secrets      ││
│  └────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

```bash
# Install tools (macOS)
brew install terraform kubectl helm awscli sops age

# Install helm-secrets plugin
helm plugin install https://github.com/jkroepke/helm-secrets

# Verify
terraform --version && kubectl version --client && helm version && sops --version && age --version
helm secrets --help

# Configure AWS
aws configure
```

---

## Step 1: Setup SOPS Encryption

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
# Note the public key (age1...)

export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
# Add to ~/.zshrc or ~/.bashrc
```

Edit `.sops.yaml` and add your public key.

---

## Step 2: Create GitHub OAuth App

1. Go to https://github.com/settings/developers
2. Click "New OAuth App"
3. Fill in:
   - **Application name:** Datavisyn Challenge
   - **Homepage URL:** https://github.com/YOUR_USERNAME/datavisyn-challenge
   - **Callback URL:** `http://localhost/oauth2/callback` (update later)
4. Save Client ID and Client Secret

---

## Step 3: Create and Encrypt Secrets

```bash
cd secrets
cp oauth2-secrets.yaml.example oauth2-secrets.yaml

# Edit with your values (structure must match Helm chart):
# config:
#   clientID: "your-github-client-id"
#   clientSecret: "your-github-client-secret"
#   cookieSecret: "$(openssl rand -base64 24)"  # Must be 32 chars!

sops --encrypt oauth2-secrets.yaml > secrets.enc.yaml
rm oauth2-secrets.yaml
cd ..
```

---

## Step 4: Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply  # ~15 minutes
cd ..
```

---

## Step 5: Configure kubectl

```bash
aws eks update-kubeconfig --region eu-central-1 --name datavisyn-dev-cluster
kubectl get nodes
```

---

## Step 6: Install Applications with Helm (Initial Setup)

### 6.1 Install Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f helm-values/ingress-nginx.yaml

# Get Load Balancer URL
kubectl get svc -n ingress-nginx ingress-nginx-controller -w
```

### 6.2 Update Callback URLs

Edit `helm-values/oauth2-proxy.yaml`:
```yaml
extraArgs:
  redirect-url: "http://YOUR_LB_URL/oauth2/callback"
```

Update GitHub OAuth App callback URL to match.

### 6.3 Install OAuth2 Proxy

```bash
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests

helm secrets install oauth2-proxy oauth2-proxy/oauth2-proxy \
  --namespace oauth2-proxy \
  --create-namespace \
  -f helm-values/oauth2-proxy.yaml \
  -f secrets://secrets/secrets.enc.yaml
```

### 6.4 Install Webapp

```bash
helm install webapp ./helm-charts/webapp \
  --namespace webapp \
  --create-namespace
```

### 6.5 Test

Open `http://YOUR_LB_URL` → GitHub login → FastAPI app

---

## Step 7: Setup ArgoCD with helm-secrets (GitOps)

### 7.1 Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

### 7.2 Configure ArgoCD for helm-secrets

```bash
# Create secret with age key
kubectl -n argocd create secret generic helm-secrets-private-keys \
  --from-file=key.txt=$HOME/.config/sops/age/keys.txt

# Allow helm-secrets URL schemes
kubectl patch configmap argocd-cm -n argocd --type merge -p '{
  "data": {
    "helm.valuesFileSchemes": "secrets+age-import,secrets+age-import-kubernetes,secrets,https"
  }
}'

# Mount age key in argocd-repo-server
kubectl patch deployment argocd-repo-server -n argocd --type=strategic -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "argocd-repo-server",
          "env": [
            {"name": "SOPS_AGE_KEY_FILE", "value": "/helm-secrets-private-keys/key.txt"},
            {"name": "HELM_SECRETS_VALUES_ALLOW_ABSOLUTE_PATH", "value": "true"}
          ],
          "volumeMounts": [
            {"mountPath": "/helm-secrets-private-keys/", "name": "helm-secrets-private-keys"}
          ]
        }],
        "volumes": [
          {"name": "helm-secrets-private-keys", "secret": {"secretName": "helm-secrets-private-keys"}}
        ]
      }
    }
  }
}'

# Wait for restart
kubectl rollout status deployment argocd-repo-server -n argocd
```

### 7.3 Push Code to GitHub

```bash
# Update argocd/applications.yaml - replace YOUR_USERNAME
git add .
git commit -m "Setup complete"
git push
```

### 7.4 Apply ArgoCD Applications

```bash
kubectl apply -f argocd/applications.yaml
```

### 7.5 Access ArgoCD UI

```bash
# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open https://localhost:8080 (admin / password)

---

## GitOps in Action

Now any changes pushed to GitHub are automatically deployed:

```bash
# Example: Change replicas
# Edit helm-charts/webapp/values.yaml
git add . && git commit -m "Scale webapp" && git push
# ArgoCD detects change and syncs automatically
```

---

## Secrets Rotation

```bash
# Edit encrypted secrets
sops secrets/secrets.enc.yaml
# Change values, save

# Push to Git - ArgoCD will sync automatically
git add . && git commit -m "Rotate secrets" && git push
```

---

## Project Structure

```
.
├── terraform/                  # AWS Infrastructure
├── helm-charts/webapp/         # FastAPI app Helm chart
├── helm-values/
│   ├── ingress-nginx.yaml
│   └── oauth2-proxy.yaml
├── secrets/
│   ├── oauth2-secrets.yaml.example
│   └── secrets.enc.yaml        # Encrypted (committed)
├── argocd/
│   └── applications.yaml       # ArgoCD apps with helm-secrets
├── .sops.yaml
└── README.md
```

---

## Cleanup

```bash
kubectl delete -f argocd/applications.yaml
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
cd terraform && terraform destroy
```
