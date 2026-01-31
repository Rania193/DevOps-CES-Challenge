# Cleanup / Teardown

**Important:** You cannot run `terraform destroy` directly. Two things will cause it to fail:

1. **Network Load Balancer**: Created by Kubernetes (not Terraform), it holds a reference to the Elastic IP. Terraform will fail trying to delete the EIP while it's still in use.
2. **ECR Repository**: Cannot be deleted if it contains Docker images. You must delete all images first, otherwise you'll get `RepositoryNotEmptyException`.

**Note:** You don't need to manually delete Kubernetes resources (pods, services, namespaces, etc.). When Terraform destroys the EKS cluster, all Kubernetes resources are automatically deleted. Only the NLB and ECR images need manual cleanup.

Follow this order:

## 1. Delete the Load Balancer Service (releases the NLB)

```bash
# Delete the ingress-nginx service that created the NLB
kubectl delete svc ingress-nginx-controller -n ingress-nginx
```

## 2. Wait for the NLB to be Deleted

The AWS cloud controller will delete the NLB when the service is removed. This can take 1-2 minutes.

```bash
# Verify no load balancers remain
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerName,State.Code]' --output table
```

Wait until your NLB no longer appears in the list, or shows as "deleted".

## 3. Delete ECR Images (Required Before Destroy)

**Important:** ECR repositories cannot be deleted if they contain images. You must delete all images first.

```bash
# Get the ECR repository name
ECR_REPO=$(cd terraform && terraform output -raw ecr_repository_name)
AWS_REGION=$(cd terraform && terraform output -raw aws_region || echo "eu-west-1")
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# List all images in the repository
aws ecr list-images --repository-name "$ECR_REPO" --region "$AWS_REGION"

# Delete all images (this deletes all tags)
aws ecr batch-delete-image \
  --repository-name "$ECR_REPO" \
  --region "$AWS_REGION" \
  --image-ids imageTag=latest \
  $(aws ecr list-images --repository-name "$ECR_REPO" --region "$AWS_REGION" --query 'imageIds[*]' --output json | jq -r '.[] | "--image-ids imageDigest=\(.imageDigest)"' | tr '\n' ' ')

# Alternative: Delete all images by digest (more thorough)
aws ecr list-images --repository-name "$ECR_REPO" --region "$AWS_REGION" --query 'imageIds[*]' --output json > /tmp/image-ids.json
aws ecr batch-delete-image \
  --repository-name "$ECR_REPO" \
  --region "$AWS_REGION" \
  --image-ids file:///tmp/image-ids.json

# Verify repository is empty
aws ecr describe-images --repository-name "$ECR_REPO" --region "$AWS_REGION"
```

**Note:** If you get `RepositoryNotEmptyException`, the repository still contains images. Make sure all images are deleted before proceeding.

## 4. Destroy Terraform Infrastructure

**Note:** When Terraform destroys the EKS cluster, all Kubernetes resources (pods, services, namespaces, etc.) are automatically deleted. You don't need to manually clean them up.

```bash
cd terraform
terraform destroy
```

## 5. Clean Up Terraform State Backend (Optional)

If you also want to remove the S3 bucket used for Terraform state:

```bash
cd terraform/bootstrap

# Empty the bucket first (required before deletion)
aws s3 rm s3://datavisyn-terraform-state-$(aws sts get-caller-identity --query Account --output text) --recursive

terraform destroy
```

## Quick Cleanup Script

For convenience, here's the full cleanup in one go:

```bash
#!/bin/bash
set -e

echo "Deleting ingress-nginx service (releases NLB)..."
kubectl delete svc ingress-nginx-controller -n ingress-nginx --ignore-not-found

echo "Waiting for NLB to be released (60 seconds)..."
sleep 60

echo "Deleting ECR images..."
ECR_REPO=$(cd terraform && terraform output -raw ecr_repository_name 2>/dev/null || echo "webapp")
AWS_REGION=$(cd terraform && terraform output -raw aws_region 2>/dev/null || echo "eu-west-1")
if aws ecr describe-images --repository-name "$ECR_REPO" --region "$AWS_REGION" --query 'imageDetails[*]' --output json 2>/dev/null | grep -q '\['; then
  echo "Found images in ECR, deleting..."
  aws ecr list-images --repository-name "$ECR_REPO" --region "$AWS_REGION" --query 'imageIds[*]' --output json > /tmp/image-ids.json
  aws ecr batch-delete-image --repository-name "$ECR_REPO" --region "$AWS_REGION" --image-ids file:///tmp/image-ids.json 2>/dev/null || echo "No images to delete"
else
  echo "ECR repository is already empty"
fi

echo "Running terraform destroy..."
cd terraform
terraform destroy -auto-approve

echo "Cleanup complete!"
```

