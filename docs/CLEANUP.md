# Cleanup / Teardown

**Important:** You cannot run `terraform destroy` directly. Two manual cleanup steps are required:

1. **Network Load Balancer**: Created by Kubernetes (not Terraform). Must be deleted before destroying infrastructure.
2. **ECR Repository**: Must be emptied of all Docker images before deletion.

**Note:** When Terraform destroys the EKS cluster, all Kubernetes resources are automatically deleted. Only the NLB and ECR images need manual cleanup.

## Manual Step-by-Step

### 1. Delete the LoadBalancer Service

```bash
kubectl delete svc ingress-nginx-controller -n ingress-nginx
```

Wait 60 seconds for AWS to delete the NLB.

### 2. Delete ECR Images

```bash
ECR_REPO=$(cd terraform && terraform output -raw ecr_repository_url 2>/dev/null | xargs basename || echo "webapp")
AWS_REGION=$(cd terraform && terraform output -raw region 2>/dev/null || echo "eu-west-1")

aws ecr batch-delete-image \
  --repository-name "$ECR_REPO" \
  --region "$AWS_REGION" \
  --image-ids "$(aws ecr list-images --repository-name "$ECR_REPO" --region "$AWS_REGION" --query 'imageIds[*]' --output json)"
```

### 3. Destroy Infrastructure

```bash
cd terraform
terraform destroy
```

## Troubleshooting

### NLB Still Exists After Service Deletion

Find and delete any remaining load balancers:

```bash
# Get VPC ID from any existing subnet in Terraform state
VPC_ID=$(terraform state list | grep 'aws_subnet' | head -1 | xargs terraform state show | grep -oP 'vpc_id\s*=\s*"\K[^"]+')

# Delete all load balancers in this VPC
for lb_arn in $(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='${VPC_ID}'].LoadBalancerArn" --output text); do
  echo "Deleting load balancer: $lb_arn"
  aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn"
done

# Wait for deletion to complete
sleep 120
```

### ECR Repository Not Empty

If batch delete fails, delete images individually:

```bash
ECR_REPO=$(cd terraform && terraform output -raw ecr_repository_url 2>/dev/null | xargs basename || echo "webapp")
AWS_REGION=$(cd terraform && terraform output -raw region 2>/dev/null || echo "eu-west-1")

aws ecr list-images --repository-name "$ECR_REPO" --region "$AWS_REGION" --output json | \
  jq -r '.imageIds[] | "\(.imageDigest)"' | \
  while read digest; do
    aws ecr batch-delete-image \
      --repository-name "$ECR_REPO" \
      --region "$AWS_REGION" \
      --image-ids "imageDigest=$digest" 2>/dev/null || true
  done
```

```bash
cd terraform/bootstrap

# Empty S3 bucket
BUCKET_NAME=$(terraform output -raw state_bucket_name 2>/dev/null)
aws s3 rm "s3://${BUCKET_NAME}" --recursive

terraform destroy
```