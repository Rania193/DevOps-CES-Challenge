# CI/CD Migration Guide

This document explains the migration from ConfigMap-based code injection to Docker images with automated CI/CD.

---

## What Changed

### Before (ConfigMap Approach)
- FastAPI code stored in Kubernetes ConfigMap
- Base image (`tiangolo/uvicorn-gunicorn-fastapi`) with code injected at runtime
- No Docker builds needed
- Code changes require ConfigMap updates

### After (Docker Image Approach)
- FastAPI code built into Docker image
- Image stored in AWS ECR
- GitHub Actions builds and pushes on every commit
- ArgoCD automatically deploys new images

---

## New Components

### 1. Application Code (`webapp/`)
```
webapp/
├── main.py           # FastAPI application
├── requirements.txt  # Python dependencies
├── Dockerfile        # Image build instructions
└── .dockerignore     # Files to exclude from build
```

### 2. GitHub Actions Workflow (`.github/workflows/deploy.yaml`)
- Builds Docker image on push to `main`
- Pushes to ECR with commit SHA as tag
- Updates Helm values.yaml with new tag
- Commits change back to repo (triggers ArgoCD sync)

### 3. Terraform Modules
- **ECR Module** (`terraform/modules/ecr/`): Creates ECR repository
- **IAM Module** (updated): Adds GitHub Actions OIDC role

---

## Setup Steps

### 1. Update Terraform Configuration

Add GitHub repo to `terraform.tfvars`:

```hcl
github_repo = "Rania193/DevOps-CES-Challenge"
```

### 2. Apply Terraform Changes

```bash
cd terraform
terraform init
terraform plan  # Review changes
terraform apply
```

This creates:
- ECR repository: `webapp`
- GitHub Actions IAM role with OIDC trust
- OIDC provider for GitHub

### 3. Get Outputs

```bash
terraform output ecr_repository_url
terraform output github_actions_role_arn
```

### 4. Configure GitHub Secrets

Go to GitHub repo → Settings → Secrets and variables → Actions

Add secret:
- **Name**: `AWS_ROLE_ARN`
- **Value**: Output from `terraform output github_actions_role_arn`

### 5. Update Helm Values

Update `helm/charts/webapp/values.yaml`:

```yaml
frontend:
  image:
    repository: "<account-id>.dkr.ecr.eu-west-1.amazonaws.com/webapp"
    tag: "latest"
    pullPolicy: Always
```

Replace `<account-id>` with your AWS account ID.

### 6. Remove ConfigMap (Optional)

The ConfigMap template is no longer needed, but you can keep it for now. The deployment no longer references it.

---

## How It Works

### CI/CD Flow

```
1. Developer pushes code to main branch
   │
   ▼
2. GitHub Actions triggers
   │
   ├─── Builds Docker image from webapp/
   │
   ├─── Tags with commit SHA (e.g., a3b8c2d)
   │
   ├─── Pushes to ECR: <account>.dkr.ecr.eu-west-1.amazonaws.com/webapp:a3b8c2d
   │
   ├─── Updates helm/charts/webapp/values.yaml:
   │    image.tag: "a3b8c2d"
   │
   └─── Commits and pushes change
        │
        ▼
3. ArgoCD detects change in values.yaml
   │
   ▼
4. ArgoCD syncs deployment
   │
   ├─── Pulls new image from ECR
   │
   └─── Restarts pods with new image
```

---

## Authentication (OIDC)

**No AWS credentials stored in GitHub!**

Instead:
1. GitHub Actions requests JWT token from GitHub
2. Assumes IAM role using OIDC (no long-lived credentials)
3. Gets temporary AWS credentials
4. Pushes to ECR

**Security benefits:**
- No secrets to rotate
- Role can only be assumed from your specific repo
- Temporary credentials (expire after 1 hour)

---

## Impact on Current Project

### What Stays the Same
- ✅ ArgoCD still manages deployments
- ✅ Helm charts still define resources
- ✅ OAuth2, TLS, Ingress all unchanged
- ✅ Same Kubernetes resources (Deployment, Service, Ingress)

### What Changes
- 🔄 Deployment now uses ECR image instead of ConfigMap
- ➕ New: GitHub Actions workflow
- ➕ New: ECR repository
- ➕ New: IAM role for GitHub Actions

### Migration Path

**Option 1: Gradual Migration**
1. Keep ConfigMap approach working
2. Add ECR + GitHub Actions
3. Test with new image tag
4. Switch deployment to ECR image
5. Remove ConfigMap later

**Option 2: Clean Cutover**
1. Set up ECR + GitHub Actions
2. Build first image
3. Update Helm values
4. Remove ConfigMap immediately

---

## Troubleshooting

### GitHub Actions Fails: "Role not found"
- Check `github_repo` variable in Terraform
- Verify IAM role was created: `aws iam list-roles | grep github-actions`
- Check OIDC provider exists: `aws iam list-open-id-connect-providers`

### Image Pull Errors
- Verify ECR repository exists
- Check IAM role has ECR permissions
- Ensure image tag matches what's in values.yaml

### ArgoCD Not Syncing
- Check if values.yaml was actually updated
- Verify ArgoCD is watching the repo
- Check ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller`

---

## Cost Impact

| Resource | Cost |
|----------|------|
| ECR Storage | ~$0.10/GB/month (first 500MB free) |
| ECR Data Transfer | Free (within same region) |
| GitHub Actions | Free (2000 minutes/month for private repos) |

**Total additional cost: ~$0-1/month** (negligible)

---

## Benefits

1. **Version Control**: Each commit = unique image tag
2. **Rollback**: Easy to revert to previous image
3. **CI/CD**: Automated builds on every push
4. **Security**: OIDC instead of long-lived credentials
5. **Best Practice**: Industry-standard Docker workflow

---

## Next Steps

1. ✅ Review this guide
2. ✅ Apply Terraform changes
3. ✅ Configure GitHub secret
4. ✅ Push code to trigger first build
5. ✅ Verify ArgoCD syncs new image
6. ✅ Test the application

---

## Questions?

Check:
- GitHub Actions logs: Repo → Actions tab
- ArgoCD UI: Check sync status
- ECR console: Verify images are being pushed

