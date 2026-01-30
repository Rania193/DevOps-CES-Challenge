# Datavisyn DevOps CES Challenge

A production-ready Kubernetes deployment on **AWS EKS** featuring OAuth2 authentication, encrypted secrets management, TLS certificates, and GitOps continuous deployment.

![Architecture Diagram](docs/architecture.png)
<!-- TODO: Add architecture diagram -->

---

## 🎯 Challenge Overview

This project demonstrates a complete DevOps workflow deploying a web application with:

- **Infrastructure as Code** - AWS resources provisioned via Terraform
- **Kubernetes Orchestration** - AWS EKS with auto-scaling node groups
- **GitOps Deployment** - ArgoCD for automated, Git-driven deployments
- **OAuth2 Authentication** - GitHub SSO protecting both the webapp and ArgoCD
- **Secrets Management** - SOPS + age encryption with helm-secrets
- **TLS Certificates** - Automated Let's Encrypt certificates via cert-manager
- **Static IP** - Elastic IP for consistent DNS configuration

---

## 🏗️ Architecture

```
                                    ┌─────────────────────────────────────────────────────────────┐
                                    │                        AWS Cloud                            │
                                    │                                                             │
┌──────────┐                        │  ┌─────────────────────────────────────────────────────┐   │
│  User    │                        │  │                    AWS EKS Cluster                   │   │
│ Browser  │                        │  │                                                      │   │
└────┬─────┘                        │  │   ┌─────────────┐      ┌─────────────────────────┐  │   │
     │                              │  │   │   ArgoCD    │◄────►│    GitHub Repository    │  │   │
     │ HTTPS                        │  │   │   (GitOps)  │      │    (Source of Truth)    │  │   │
     ▼                              │  │   └─────────────┘      └─────────────────────────┘  │   │
┌─────────────┐    ┌────────────┐   │  │                                                      │   │
│  DuckDNS    │───►│  Elastic   │   │  │   ┌─────────────┐    ┌──────────────┐    ┌───────┐  │   │
│ (DNS)       │    │    IP      │───┼──┼──►│   NGINX     │───►│ OAuth2-Proxy │───►│Webapp │  │   │
└─────────────┘    └────────────┘   │  │   │  Ingress    │    │  (GitHub)    │    │(Fast  │  │   │
                                    │  │   │ Controller  │    └──────────────┘    │ API)  │  │   │
                                    │  │   └──────┬──────┘                        └───────┘  │   │
                                    │  │          │                                          │   │
                                    │  │   ┌──────▼──────┐                                   │   │
                                    │  │   │cert-manager │                                   │   │
                                    │  │   │(TLS certs)  │                                   │   │
                                    │  │   └─────────────┘                                   │   │
                                    │  └──────────────────────────────────────────────────────┘   │
                                    │                                                             │
                                    │  ┌─────────────────────────────────────────────────────┐   │
                                    │  │  VPC: 10.0.0.0/16 │ 3 AZs │ Public + Private Subnets│   │
                                    │  └─────────────────────────────────────────────────────┘   │
                                    └─────────────────────────────────────────────────────────────┘
```

### Component Overview

| Component | Purpose | Technology |
|-----------|---------|------------|
| **Infrastructure** | Cloud resources | Terraform + AWS (VPC, EKS, IAM) |
| **Ingress** | Traffic routing & TLS | NGINX Ingress Controller |
| **Authentication** | GitHub OAuth2 SSO | oauth2-proxy |
| **Certificates** | Automated TLS | cert-manager + Let's Encrypt |
| **Secrets** | Encrypted secrets in Git | SOPS + age + helm-secrets |
| **GitOps** | Automated deployments | ArgoCD |
| **Application** | Demo webapp | FastAPI (Python) |

---

## 📁 Project Structure

```
├── argocd/
│   ├── apps/                      # ArgoCD Application manifests
│   │   ├── cert-manager.yaml      # TLS certificate management
│   │   ├── ingress-nginx.yaml     # Load balancer & routing
│   │   ├── oauth2-proxy.yaml      # GitHub authentication
│   │   └── webapp.yaml            # Main application
│   └── config/                    # ArgoCD configuration
│       ├── argocd-github-oauth.yaml
│       ├── argocd-ingress.yaml    # External access with TLS
│       └── argocd-cmd-params-cm.yaml
├── helm/
│   ├── charts/
│   │   └── webapp/                # Custom Helm chart
│   │       ├── Chart.yaml
│   │       ├── templates/
│   │       └── values.yaml
│   └── values/                    # External chart overrides
│       ├── cert-manager.yaml
│       ├── ingress-nginx.yaml
│       └── oauth2-proxy.yaml
├── secrets/
│   ├── secrets.enc.yaml           # Encrypted secrets (safe to commit)
│   └── secrets.yaml.example       # Template for secrets
├── terraform/
│   ├── bootstrap/                 # S3 backend for state
│   └── modules/
│       ├── eks/                   # EKS cluster
│       ├── iam/                   # IAM roles & policies
│       └── vpc/                   # Network infrastructure
├── docs/                          # Documentation & diagrams
└── README.md
```

---

## 🔧 Prerequisites

### Required Tools

```bash
# macOS
brew install terraform kubectl helm awscli sops age

# Install helm-secrets plugin
helm plugin install https://github.com/jkroepke/helm-secrets

# Verify installations
terraform --version    # >= 1.5.0
kubectl version        # >= 1.25
helm version           # >= 3.0
aws --version          # AWS CLI v2
sops --version
age --version
```

### AWS Configuration

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and region (eu-west-1)
```

### SOPS/age Setup

```bash
# Generate encryption key
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# Note the public key (starts with age1...)
cat ~/.config/sops/age/keys.txt

# Add to shell profile
echo 'export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt' >> ~/.zshrc
source ~/.zshrc
```

---

## 🚀 Deployment Guide

### Step 1: Clone and Configure

```bash
git clone https://github.com/YOUR_USERNAME/DevOps-CES-Challenge.git
cd DevOps-CES-Challenge

# Update .sops.yaml with your age public key
```

### Step 2: Bootstrap Terraform State

```bash
cd terraform/bootstrap
terraform init
terraform apply
# Creates S3 bucket and DynamoDB table for state management
```

### Step 3: Deploy Infrastructure

```bash
cd ../  # Back to terraform/

# IMPORTANT: Set node count to 2 (t3.medium can only run ~17 pods)
# Edit terraform.tfvars: node_desired_size = 2

terraform init
terraform apply
# Takes ~15-20 minutes
```

### Step 4: Configure kubectl

```bash
aws eks update-kubeconfig --region eu-west-1 --name datavisyn-dev-cluster
kubectl get nodes
# Should show 2 nodes
```

### Step 5: Get Static IP for DNS

```bash
terraform output nlb_eip_public_ip
# Example: 54.77.17.178 - This is your PERMANENT IP!
```

### Step 6: Configure DNS (DuckDNS)

1. Go to https://www.duckdns.org
2. Create two domains pointing to your Elastic IP:
   - `datavisyn-demo` → webapp
   - `datavisyn-argocd` → ArgoCD UI

### Step 7: Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

### Step 8: Configure helm-secrets in ArgoCD

```bash
# Create secret with age key
kubectl -n argocd create secret generic helm-secrets-private-keys \
  --from-file=key.txt=$HOME/.config/sops/age/keys.txt

# Enable helm-secrets schemes
kubectl patch configmap argocd-cm -n argocd --type merge -p \
  '{"data":{"helm.valuesFileSchemes":"secrets+age-import,secrets+age-import-kubernetes,secrets,https"}}'

# Mount age key in repo-server
kubectl patch deployment argocd-repo-server -n argocd \
  --patch-file argocd/config/argocd-repo-server-patch.yaml

kubectl rollout status deployment/argocd-repo-server -n argocd
```

### Step 9: Create GitHub OAuth Apps

You need **TWO** OAuth apps:

| App | Homepage URL | Callback URL |
|-----|--------------|--------------|
| **Webapp** | `https://datavisyn-demo.duckdns.org` | `https://datavisyn-demo.duckdns.org/oauth2/callback` |
| **ArgoCD** | `https://datavisyn-argocd.duckdns.org` | `https://datavisyn-argocd.duckdns.org/api/dex/callback` |

1. Go to https://github.com/settings/developers
2. Create each OAuth App and save the Client ID and Client Secret

### Step 10: Configure Secrets

```bash
# Edit secrets file
sops secrets/secrets.enc.yaml

# Update with webapp OAuth credentials:
# oauth2:
#   clientID: "your-webapp-client-id"
#   clientSecret: "your-webapp-client-secret"
#   cookieSecret: "$(openssl rand -base64 32)"
```

### Step 11: Configure ArgoCD OAuth

```bash
# Add ArgoCD OAuth credentials to argocd-secret
kubectl -n argocd patch secret argocd-secret --type='json' -p="[
  {\"op\": \"add\", \"path\": \"/data/dex.github.clientID\", \"value\": \"$(echo -n 'YOUR_ARGOCD_CLIENT_ID' | base64)\"},
  {\"op\": \"add\", \"path\": \"/data/dex.github.clientSecret\", \"value\": \"$(echo -n 'YOUR_ARGOCD_CLIENT_SECRET' | base64)\"}
]"

# Apply ArgoCD configuration
kubectl apply -f argocd/config/argocd-github-oauth.yaml
kubectl apply -f argocd/config/argocd-cmd-params-cm.yaml
kubectl apply -f argocd/config/argocd-ingress.yaml

# Restart ArgoCD
kubectl -n argocd rollout restart deployment argocd-server argocd-dex-server
```

### Step 12: Deploy Applications

```bash
# Commit and push any changes
git add -A
git commit -m "Configure deployment"
git push

# Deploy all applications via ArgoCD
kubectl apply -f argocd/apps/
```

### Step 13: Verify Deployment

```bash
# Check all applications are synced
kubectl get applications -n argocd

# Check certificates are issued
kubectl get certificate -A

# Check all pods are running
kubectl get pods -A
```

---

## ✅ Verification

### Test Webapp Authentication

1. Open https://datavisyn-demo.duckdns.org
2. You should be redirected to GitHub login
3. After authentication, you'll see the webapp

![Webapp Screenshot](docs/screenshots/webapp.png)
<!-- TODO: Add webapp screenshot -->

### Test ArgoCD Authentication

1. Open https://datavisyn-argocd.duckdns.org
2. Click "LOG IN VIA GITHUB"
3. After authentication, you'll see the ArgoCD dashboard

![ArgoCD Screenshot](docs/screenshots/argocd.png)
<!-- TODO: Add ArgoCD screenshot -->

### Verify TLS Certificates

```bash
# Check certificate status
kubectl get certificate -A
# All should show READY: True

# Verify in browser - padlock icon should appear
```

---

## 🔐 Secrets Management

### How Secrets Work

1. **Secrets are encrypted** using SOPS + age before committing to Git
2. **ArgoCD decrypts** secrets at deployment time using helm-secrets
3. **Kubernetes receives** plaintext secrets (never stored in Git)

### Rotating Secrets

```bash
# 1. Edit the encrypted secrets file
sops secrets/secrets.enc.yaml

# 2. Update the values you want to rotate
# oauth2:
#   clientSecret: "new-secret-value"
#   cookieSecret: "new-cookie-secret"

# 3. Save and commit
git add secrets/secrets.enc.yaml
git commit -m "Rotate OAuth secrets"
git push

# 4. ArgoCD automatically detects changes and redeploys
#    Or manually sync: argocd app sync oauth2-proxy
```

### Rotating ArgoCD OAuth Credentials

```bash
# Update the secret directly
kubectl -n argocd patch secret argocd-secret --type='json' -p="[
  {\"op\": \"replace\", \"path\": \"/data/dex.github.clientSecret\", \"value\": \"$(echo -n 'NEW_SECRET' | base64)\"}
]"

# Restart Dex server
kubectl -n argocd rollout restart deployment argocd-dex-server
```

### Generating New Encryption Keys

```bash
# Generate new age key
age-keygen -o new-key.txt

# Re-encrypt secrets with new key
sops --rotate --in-place secrets/secrets.enc.yaml

# Update .sops.yaml with new public key
# Distribute new key to ArgoCD
kubectl -n argocd delete secret helm-secrets-private-keys
kubectl -n argocd create secret generic helm-secrets-private-keys \
  --from-file=key.txt=new-key.txt
```

---

## 🏭 Demo vs Production

This project uses a **cost-optimized demo configuration**:

| Aspect | Demo (This Project) | Production |
|--------|---------------------|------------|
| **Availability** | Single AZ | Multi-AZ (3 AZs) |
| **Elastic IPs** | 1 EIP (~$3.65/mo) | 3 EIPs (~$11/mo) |
| **DNS** | DuckDNS (free) | Route 53 (~$0.50/mo) |
| **Nodes** | 2x t3.medium | Auto-scaling group |
| **Total Cost** | ~$75/month | ~$150+/month |

### Production Recommendations

1. **Use Route 53** - ALIAS records handle dynamic NLB IPs automatically
2. **Enable Multi-AZ** - Survive availability zone failures
3. **Add monitoring** - Prometheus + Grafana for observability
4. **Configure backups** - Regular EKS and secrets backups
5. **Use private subnets** - Worker nodes in private subnets only

---

## 🧹 Cleanup

To destroy all resources:

```bash
# Delete ArgoCD applications first
kubectl delete -f argocd/apps/

# Delete ArgoCD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Destroy infrastructure
cd terraform
terraform destroy

# Destroy state backend (optional)
cd bootstrap
terraform destroy
```

---

## 📚 Architecture Decisions

### Why AWS EKS?
- Managed Kubernetes reduces operational overhead
- Native AWS integrations (IAM, VPC, ALB)
- Auto-scaling and high availability built-in

### Why ArgoCD + GitOps?
- Git becomes the single source of truth
- Automated deployments on every push
- Easy rollbacks via Git history
- Audit trail of all changes

### Why SOPS + age over Sealed Secrets?
- Secrets can be edited locally before committing
- Works with any Git provider
- No cluster-side controller required for encryption
- Better developer experience

### Why oauth2-proxy over ALB OIDC?
- Works with any ingress controller
- More flexible authentication rules
- Easier to test locally
- Better control over session management

### Why Elastic IP?
- Static IP for DNS configuration
- No need to update DNS when NLB recreates
- Required for DuckDNS (doesn't support CNAME)

---

## 🔗 References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [helm-secrets Plugin](https://github.com/jkroepke/helm-secrets)
- [oauth2-proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)

---

## 📸 Screenshots

### ArgoCD Dashboard
![ArgoCD Dashboard](docs/screenshots/argocd-dashboard.png)
<!-- TODO: Add screenshot -->

### Application Sync Status
![App Sync](docs/screenshots/argocd-apps.png)
<!-- TODO: Add screenshot -->

### GitHub OAuth Login
![OAuth Login](docs/screenshots/github-oauth.png)
<!-- TODO: Add screenshot -->

### Webapp
![Webapp](docs/screenshots/webapp.png)
<!-- TODO: Add screenshot -->

---

## 👤 Author

Built for the Datavisyn DevOps CES Challenge.
