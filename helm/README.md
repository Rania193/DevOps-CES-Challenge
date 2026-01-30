# Helm Charts & Values

## Structure

```
helm/
├── charts/           # Custom Helm charts
│   └── webapp/       # Main application chart
└── values/           # Values for external charts
    ├── cert-manager.yaml
    ├── ingress-nginx.yaml
    └── oauth2-proxy.yaml
```

## Custom Charts

### webapp
The main application chart that deploys:
- FastAPI application (ConfigMap-customized)
- Kubernetes Service
- Ingress with OAuth2 protection
- TLS certificate via cert-manager

## External Chart Values

Configuration overrides for third-party Helm charts:

| Chart | Purpose |
|-------|---------|
| cert-manager | Let's Encrypt TLS certificates |
| ingress-nginx | Load balancer with static Elastic IP |
| oauth2-proxy | GitHub authentication |

