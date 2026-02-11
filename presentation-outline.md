# DevOps CES Challenge - Presentation Outline

## Slide 1: Title
- **Datavisyn DevOps Challenge**
- Kubernetes deployment on AWS EKS
- GitHub OAuth, GitOps, CI/CD automation
- [Your Name/Date]

## Slide 2: Overview
- **What we built:**
  - Production-ready Kubernetes platform on AWS EKS
  - Automated CI/CD pipeline
  - Secure authentication with GitHub OAuth
  - Encrypted secrets management
  - GitOps-based continuous deployment

## Slide 3: Architecture Diagram
- Show architecture diagram
- High-level flow: User → NLB → Ingress → OAuth2 Proxy → Webapp
- CI/CD: GitHub → Actions → ECR → ArgoCD → Cluster

## Slide 4: Key Components
- **Infrastructure:**
  - AWS EKS cluster
  - Network Load Balancer + Elastic IP
  - VPC with NAT gateway
  
- **Application Layer:**
  - FastAPI webapp (containerized)
  - NGINX Ingress Controller
  - OAuth2 Proxy for authentication

## Slide 5: Key Components (continued)
- **DevOps Tools:**
  - ArgoCD (GitOps)
  - GitHub Actions (CI/CD)
  - cert-manager (TLS automation)
  - SOPS + helm-secrets (secrets encryption)

## Slide 6: Design Choice 1 - GitOps with ArgoCD
- **Why GitOps?**
  - Single source of truth (Git)
  - Automatic drift detection and reconciliation
  - Auditable deployments via Git history
  - Separation of CI and CD

## Slide 7: Design Choice 2 - OAuth2 Proxy
- **Why externalize authentication?**
  - Keeps application stateless
  - Easy to swap auth providers
  - No code changes needed
  - Centralized session management

## Slide 8: Design Choice 3 - Secrets Management
- **SOPS + age encryption:**
  - Version-controlled encrypted secrets
  - Decryption at deploy time (not in CI logs)
  - Cloud-agnostic (no vendor lock-in)
  - Helm-secrets integration with ArgoCD

## Slide 9: Design Choice 4 - Security
- **GitHub Actions OIDC:**
  - No long-lived AWS credentials
  - Repository-scoped IAM role
  - Follows AWS security best practices
  
- **TLS automation:**
  - cert-manager with Let's Encrypt
  - Automatic renewal

## Slide 10: CI/CD Pipeline Flow
1. Developer pushes code to `webapp/`
2. GitHub Actions builds Docker image
3. Image pushed to ECR (tagged with commit SHA)
4. Helm values updated automatically
5. ArgoCD detects change and deploys
6. New version live in ~5 minutes

## Slide 11: Authentication Flow
1. User accesses webapp URL
2. OAuth2 Proxy checks authentication
3. Redirect to GitHub OAuth if not authenticated
4. GitHub callback sets session cookie
5. Authenticated requests forwarded to webapp

## Slide 12: Project Structure
- Terraform: Infrastructure as Code
- Helm: Application packaging
- ArgoCD: GitOps manifests
- GitHub Actions: CI/CD automation
- Secrets: Encrypted with SOPS

## Slide 13: Key Features
- ✅ Fully automated deployments
- ✅ Zero-downtime updates
- ✅ Encrypted secrets in Git
- ✅ OAuth authentication
- ✅ Automatic TLS certificates
- ✅ Infrastructure as Code
- ✅ GitOps best practices

## Slide 14: Design Choices - Customer Perspective
- **Why these choices matter for maintenance:**

**GitOps (ArgoCD):**
  - All changes tracked in Git - easy to audit and rollback
  - No manual cluster changes - prevents configuration drift
  - Self-healing - automatically fixes manual modifications

**Encrypted Secrets in Git:**
  - Secrets version-controlled alongside code
  - Easy rotation via standard Git workflow
  - No separate secret management system needed

**Infrastructure as Code (Terraform):**
  - Reproducible infrastructure
  - Easy to recreate or scale
  - Clear documentation of what's deployed

## Slide 15: Design Choices - Customer Perspective (continued)
- **Operational Benefits:**

**OAuth2 Proxy:**
  - Change auth provider without touching application code
  - Centralized authentication management
  - Easy to add multi-factor authentication later

**Automated TLS (cert-manager):**
  - No manual certificate renewal
  - Automatic HTTPS for all services
  - No certificate expiry incidents

**GitHub Actions OIDC:**
  - No AWS access keys to manage or rotate
  - Repository-scoped permissions (least privilege)
  - Secure by default

## Slide 16: Future Improvements
- **High Availability:**
  - **Multi-AZ EIPs for NLB**: Currently single EIP in one AZ. Production needs EIPs per availability zone for redundancy (~$11/month vs $3.65/month)
  - **Multiple NAT Gateways**: Single NAT gateway is a single point of failure. Deploy one per AZ for high availability
  - **Pod Disruption Budgets**: Ensure minimum pods available during node updates
  - **Health checks**: Add liveness and readiness probes to deployments

- **Multi-Environment Setup:**
  - Separate clusters for dev/staging/prod (helm or kustomize or others)
  - Environment-specific Helm value overrides
  - Separate ArgoCD applications per environment
  - Route 53 instead of DuckDNS for production-grade DNS management

## Slide 17: Future Improvements (continued)
- **Observability & Monitoring:**
  - Prometheus + Grafana for metrics and dashboards
  - CloudWatch Container Insights for EKS monitoring
  - Centralized logging (CloudWatch Logs or ELK stack)
  - Alerting for pod failures, high CPU/memory, certificate expiry

- **Cost & Performance Optimization:**
  - Cluster Autoscaler addon for automatic node scaling
  - Spot instances for non-critical workloads (up to 90% cost savings)
  - Horizontal Pod Autoscaler based on CPU/memory metrics
  - Resource quotas and limit ranges to prevent resource exhaustion

- **Security & Compliance:**
  - Kubernetes Network Policies for pod-to-pod communication control
  - Pod Security Standards enforcement
  - Container image scanning in CI/CD pipeline


## Slide 18: Demo / Screenshots
- Webapp with authentication
- ArgoCD dashboard
- GitHub Actions workflow
- Architecture diagram

## Slide 19: Takeaways
- **Production-ready patterns:**
  - GitOps for reliability
  - OIDC for secure CI/CD
  - Encrypted secrets management
  - Automated TLS provisioning
  
- **Maintainable:**
  - All infrastructure in code
  - Clear documentation
  - Easy secret rotation

## Slide 20: Q&A
- Questions?

