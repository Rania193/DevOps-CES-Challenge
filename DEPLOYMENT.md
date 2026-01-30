# 🚀 Deployment Guide

Complete step-by-step guide to deploy this project.

## Prerequisites

Make sure you have these tools installed:

```bash
# Check versions
aws --version        # AWS CLI v2
terraform --version  # >= 1.5.0
kubectl version      # >= 1.25
helm version         # >= 3.0
sops --version       # For secrets encryption
```

**AWS Setup:**
- AWS account with admin access
- AWS CLI configured: `aws configure`

---

## Step 1: Bootstrap Terraform State (One-Time)

This creates an S3 bucket to store Terraform state remotely.

```bash
cd terraform/bootstrap

terraform init
terraform apply
```

Type `yes` when prompted. This creates:
- S3 bucket: `ces-challenge-terraform-state`
- DynamoDB table: `ces-challenge-terraform-lock`

---

## Step 2: Deploy Infrastructure

This creates the VPC, EKS cluster, and IAM roles.

> ⚠️ **IMPORTANT: Node Capacity**
> 
> t3.medium instances can only run ~17 pods. With all our apps (ArgoCD, cert-manager, 
> ingress-nginx, oauth2-proxy, webapp), you'll hit this limit!
> 
> **Set `node_desired_size = 2`** in `terraform.tfvars` before applying:
> ```hcl
> node_desired_size = 2   # Need at least 2 nodes for all pods
> ```

```bash
cd ../   # Back to terraform/ directory

terraform init
terraform apply
```

Type `yes` when prompted. **This takes ~15-20 minutes.**

When complete, configure kubectl:

```bash
# Copy the command from terraform output, or run:
aws eks update-kubeconfig --region eu-west-1 --name datavisyn-dev-cluster
```

Verify connection:

```bash
kubectl get nodes
# Should show 2 worker nodes
```

### Get Static IP Info

Terraform creates an Elastic IP for the load balancer (so the IP never changes):

```bash
# Get the allocation ID (for ingress-nginx config)
terraform output nlb_eip_allocation_id
# Example: eipalloc-0abc123def456

# Get the static IP (for DuckDNS)
terraform output nlb_eip_public_ip
# Example: 34.251.10.50  <-- This is your PERMANENT IP!

# Get the subnet ID (for single-AZ load balancer)
terraform output nlb_subnet_id
# Example: subnet-0abc123def456
```

### Update ingress-nginx.yaml

Edit `helm/values/ingress-nginx.yaml` and replace the placeholders with your actual values:

```yaml
service.beta.kubernetes.io/aws-load-balancer-eip-allocations: "eipalloc-xxx"
service.beta.kubernetes.io/aws-load-balancer-subnets: "subnet-xxx"
```

Commit and push:
```bash
git add helm/values/ingress-nginx.yaml
git commit -m "Configure static EIP for NLB"
git push
```

---

## Step 3: Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready (~2 minutes)
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

Get ArgoCD admin password (for initial login):

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo  # Print newline
```

Access ArgoCD UI:

```bash
# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open: https://localhost:8080
# Username: admin
# Password: (from command above)
```

---

## Step 3.5: (Optional) Enable GitHub Login for ArgoCD

Instead of using username/password, you can login to ArgoCD with GitHub!

### Create GitHub OAuth App

1. Go to https://github.com/settings/developers
2. Click "New OAuth App"
3. Fill in:
   - **Application name:** `datavisyn-argocd`
   - **Homepage URL:** `https://localhost:8080` (must be HTTPS!)
   - **Authorization callback URL:** `https://localhost:8080/api/dex/callback`
4. Click "Register application"
5. Copy the **Client ID**
6. Generate and copy a **Client Secret**

### Add Credentials to ArgoCD

> ⚠️ **IMPORTANT: ArgoCD Secret Format**
> 
> ArgoCD reads secrets from the main `argocd-secret`, NOT separate secrets!
> The key format must be: `dex.github.clientID` and `dex.github.clientSecret`

```bash
# Replace YOUR_CLIENT_ID and YOUR_CLIENT_SECRET with your actual values
kubectl -n argocd patch secret argocd-secret --type='json' -p="[
  {\"op\": \"add\", \"path\": \"/data/dex.github.clientID\", \"value\": \"$(echo -n 'YOUR_CLIENT_ID' | base64)\"},
  {\"op\": \"add\", \"path\": \"/data/dex.github.clientSecret\", \"value\": \"$(echo -n 'YOUR_CLIENT_SECRET' | base64)\"}
]"
```

### Apply Configuration

```bash
kubectl apply -f argocd/config/argocd-github-oauth.yaml
```

### Fix RBAC Permissions

> ⚠️ **IMPORTANT: Username Format**
> 
> ArgoCD sees your **GitHub email** as the username, NOT your GitHub username!
> Check "User Info" in ArgoCD sidebar to see your actual username.

```bash
# Update RBAC with your GitHub email (check User Info in ArgoCD UI for exact value)
kubectl patch configmap argocd-rbac-cm -n argocd --type merge -p '{
  "data": {
    "policy.csv": "g, YOUR_GITHUB_EMAIL@gmail.com, role:admin",
    "policy.default": "role:readonly"
  }
}'

# Or for demo, give everyone admin access:
kubectl patch configmap argocd-rbac-cm -n argocd --type merge -p '{"data":{"policy.default":"role:admin"}}'
```

### Restart ArgoCD

```bash
kubectl -n argocd rollout restart deployment argocd-server argocd-dex-server
kubectl -n argocd rollout status deployment argocd-dex-server
```

### Verify Setup

```bash
# Check for errors - should NOT show "key does not exist" warnings
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-dex-server --tail=20
```

### Access ArgoCD

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080
# Click "LOG IN VIA GITHUB"
```

---

## Step 4: Set Up Secrets for helm-secrets

ArgoCD needs your age key to decrypt secrets.

```bash
# Create the secret with your age key
kubectl -n argocd create secret generic helm-secrets-private-keys \
  --from-file=key.txt=$HOME/.config/sops/age/keys.txt

# Update ArgoCD config to allow secrets schemes
kubectl patch configmap argocd-cm -n argocd --type merge -p '{"data":{"helm.valuesFileSchemes":"secrets+age-import,secrets+age-import-kubernetes,secrets,https"}}'

# Apply the repo-server patch for helm-secrets
kubectl patch deployment argocd-repo-server -n argocd --patch-file argocd/config/argocd-repo-server-patch.yaml

# Wait for repo-server to restart
kubectl rollout status deployment/argocd-repo-server -n argocd
```

---

## Step 5: Deploy Applications via ArgoCD

```bash
# Apply all ArgoCD applications
kubectl apply -f argocd/apps/
```

This deploys (in order via sync-waves):
1. **cert-manager** - For SSL certificates
2. **ingress-nginx** - Load balancer & traffic routing
3. **oauth2-proxy** - GitHub authentication
4. **webapp** - Your application

Watch the deployments:

```bash
# Check ArgoCD application status
kubectl get applications -n argocd

# Or watch all pods
kubectl get pods -A -w
```

> ⚠️ **If cert-manager-webhook is stuck in Pending:**
> 
> This usually means "Too many pods" on the node. Check with:
> ```bash
> kubectl describe pod -n cert-manager -l app.kubernetes.io/component=webhook | tail -10
> ```
> 
> Fix by adding another node:
> ```bash
> aws eks update-nodegroup-config \
>   --cluster-name datavisyn-dev-cluster \
>   --nodegroup-name datavisyn-dev-nodes \
>   --scaling-config desiredSize=2 \
>   --region eu-west-1
> ```

---

## Step 6: Get Load Balancer URL

Wait for ingress-nginx to create the AWS Load Balancer (~2-3 minutes):

```bash
# Get the ELB hostname
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Or just the hostname:
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## Step 7: Update DuckDNS

Point your DuckDNS domain to the **static Elastic IP**:

```bash
# Get your static IP (from Terraform output earlier)
cd terraform
terraform output nlb_eip_public_ip
```

Go to https://www.duckdns.org and set your domain's IP to this value.

> ✅ **This IP is permanent!** Unlike the default ELB, this Elastic IP never changes.
> You only need to set it once.

---

## Step 8: Configure GitHub OAuth App (for webapp)

This is a SEPARATE OAuth app from the ArgoCD one!

1. Go to: https://github.com/settings/developers
2. Click "New OAuth App"
3. Fill in:
   - **Application name:** `datavisyn-webapp`
   - **Homepage URL:** `https://datavisyn-demo.duckdns.org`
   - **Authorization callback URL:** `https://datavisyn-demo.duckdns.org/oauth2/callback`
4. Click "Register application"
5. Copy the **Client ID**
6. Generate a new **Client Secret** and copy it

---

## Step 9: Update Secrets

Update your encrypted secrets with the GitHub OAuth credentials:

```bash
# Generate a cookie secret first
openssl rand -base64 32

# Edit the secrets file (sops will decrypt/encrypt automatically)
sops secrets/secrets.enc.yaml
```

Update the values:
```yaml
oauth2:
  clientID: "your-github-client-id"
  clientSecret: "your-github-client-secret"
  cookieSecret: "your-generated-cookie-secret"
```

Save and commit:
```bash
git add secrets/secrets.enc.yaml
git commit -m "Update OAuth secrets"
git push
```

ArgoCD will automatically redeploy oauth2-proxy with the new secrets.

---

## Step 10: Verify & Test

1. **Check all pods are running:**
```bash
kubectl get pods -A
```

2. **Check certificate is issued:**
```bash
kubectl get certificate -A
# Should show "Ready: True"

kubectl get clusterissuer
# Should show "letsencrypt-prod"
```

3. **Visit your app:**
```
https://datavisyn-demo.duckdns.org
```

You should be redirected to GitHub login, then see your webapp!

---

## Troubleshooting

### "Too many pods" - Pod stuck in Pending

t3.medium can only run ~17 pods. Add another node:

```bash
aws eks update-nodegroup-config \
  --cluster-name datavisyn-dev-cluster \
  --nodegroup-name datavisyn-dev-nodes \
  --scaling-config desiredSize=2 \
  --region eu-west-1

# Wait for node
kubectl get nodes -w
```

### ArgoCD GitHub OAuth - "key does not exist in secret"

You're using the wrong secret format. The credentials must be in `argocd-secret`:

```bash
kubectl -n argocd patch secret argocd-secret --type='json' -p="[
  {\"op\": \"add\", \"path\": \"/data/dex.github.clientID\", \"value\": \"$(echo -n 'YOUR_CLIENT_ID' | base64)\"},
  {\"op\": \"add\", \"path\": \"/data/dex.github.clientSecret\", \"value\": \"$(echo -n 'YOUR_CLIENT_SECRET' | base64)\"}
]"

kubectl -n argocd rollout restart deployment argocd-dex-server
```

### ArgoCD - "permission denied" when syncing

Your GitHub email needs admin permissions:

```bash
# Check your username in ArgoCD UI > User Info

# Update RBAC
kubectl patch configmap argocd-rbac-cm -n argocd --type merge -p '{
  "data": {
    "policy.csv": "g, your.email@gmail.com, role:admin",
    "policy.default": "role:readonly"
  }
}'

kubectl -n argocd rollout restart deployment argocd-server
```

### ArgoCD OAuth - "Invalid redirect URL"

Make sure URLs use `https://` (ArgoCD uses HTTPS by default):

- Homepage URL: `https://localhost:8080`
- Callback URL: `https://localhost:8080/api/dex/callback`

### cert-manager webhook errors

If sync fails with "no endpoints available for service cert-manager-webhook":

1. Check webhook pod is running: `kubectl get pods -n cert-manager`
2. If Pending, add more nodes (see "Too many pods" above)
3. Once running, force re-sync in ArgoCD UI

### Certificate not issuing

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate status
kubectl describe certificate -n webapp

# Check ClusterIssuer exists
kubectl get clusterissuer
```

### ArgoCD apps not syncing

```bash
# Check app status
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd
```

### Can't reach the app

```bash
# Check ingress
kubectl get ingress -A
kubectl describe ingress -n webapp

# Check Load Balancer
kubectl get svc -n ingress-nginx

# Verify the ELB has the correct Elastic IP
kubectl get svc -n ingress-nginx ingress-nginx-controller -o yaml | grep -A5 "status:"
```

### Load Balancer IP keeps changing

If you didn't configure the Elastic IP, the NLB IP will change. Fix by:

1. Get your EIP allocation ID: `terraform output nlb_eip_allocation_id`
2. Get your subnet ID: `terraform output nlb_subnet_id`
3. Update `helm/values/ingress-nginx.yaml` with these values
4. Commit, push, and sync ingress-nginx in ArgoCD

---

## Demo vs Production: Load Balancer Configuration

This project uses a **cost-optimized demo setup**. Here's how it differs from production:

### Demo Setup (This Project)
| Aspect | Configuration | Cost |
|--------|--------------|------|
| Elastic IPs | 1 EIP in single AZ | ~$3.65/month |
| Availability | Single AZ - if AZ fails, app is down | - |
| DNS | DuckDNS (free dynamic DNS) | Free |
| Total | Good for demos & interviews | ~$4/month |

### Production Setup
| Aspect | Configuration | Cost |
|--------|--------------|------|
| Elastic IPs | 1 EIP per AZ (3 AZs) | ~$11/month |
| Availability | Multi-AZ - survives AZ failures | - |
| DNS | Route 53 with ALIAS record | ~$0.50/month |
| Total | High availability | ~$12/month |

### Production Changes

**Option A: Multi-AZ with Elastic IPs**

```yaml
# helm/values/ingress-nginx.yaml
service.beta.kubernetes.io/aws-load-balancer-eip-allocations: "eipalloc-az1,eipalloc-az2,eipalloc-az3"
# Remove the subnets annotation to use all AZs
```

Update Terraform to create 3 EIPs:
```hcl
# terraform/modules/vpc/main.tf
resource "aws_eip" "nlb" {
  count  = length(var.availability_zones)  # 3 EIPs
  ...
}
```

**Option B: Route 53 (Recommended for Production)**

No Elastic IPs needed! AWS handles IP changes automatically.

```yaml
# helm/values/ingress-nginx.yaml - Remove EIP annotations entirely
controller:
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
      # No eip-allocations or subnets - NLB uses all AZs automatically
```

Then in Route 53:
1. Create a hosted zone for your domain
2. Create an ALIAS record pointing to the NLB hostname
3. AWS automatically resolves to healthy NLB IPs

**Why Route 53 ALIAS is better:**
- No Elastic IP costs
- Automatic failover between AZs
- Health checks built-in
- Works with dynamic NLB IPs

---

## Quick Reference: Two GitHub OAuth Apps

This project uses **TWO** GitHub OAuth apps:

| App | Purpose | Callback URL |
|-----|---------|--------------|
| `datavisyn-argocd` | Login to ArgoCD UI | `https://localhost:8080/api/dex/callback` |
| `datavisyn-webapp` | Protect the webapp | `https://datavisyn-demo.duckdns.org/oauth2/callback` |

---

## Cleanup

To destroy everything:

```bash
# Delete ArgoCD apps first
kubectl delete -f argocd/apps/

# Destroy infrastructure
cd terraform
terraform destroy

# Destroy bootstrap (optional - keeps state bucket)
cd bootstrap
terraform destroy
```
