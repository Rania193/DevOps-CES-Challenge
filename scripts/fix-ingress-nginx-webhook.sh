#!/bin/bash
# Fix ingress-nginx admission webhook CA bundle
# This is a known issue where the admission-create job doesn't always
# properly set the CA bundle in the validatingwebhookconfiguration
#
# Run this after installing ingress-nginx if ingresses fail to create with:
# "failed calling webhook: tls: failed to verify certificate"

set -e

echo "Fixing ingress-nginx admission webhook CA bundle..."

# Wait for the admission secret to be created
echo "Waiting for ingress-nginx-admission secret..."
kubectl wait --for=jsonpath='{.data.ca}' --timeout=60s secret/ingress-nginx-admission -n ingress-nginx

# Wait for the admission-create job to complete
echo "Waiting for admission-create job to complete..."
kubectl wait --for=condition=complete --timeout=60s job/ingress-nginx-admission-create -n ingress-nginx 2>/dev/null || echo "Job may have already completed"

# Get the CA bundle from the secret and patch the webhook
CA_BUNDLE=$(kubectl get secret ingress-nginx-admission -n ingress-nginx -o jsonpath='{.data.ca}')

if [ -z "$CA_BUNDLE" ]; then
  echo "Error: Could not get CA bundle from secret"
  exit 1
fi

echo "Patching validatingwebhookconfiguration with CA bundle..."
kubectl patch validatingwebhookconfiguration ingress-nginx-admission \
  --type='json' \
  -p="[{\"op\": \"replace\", \"path\": \"/webhooks/0/clientConfig/caBundle\", \"value\": \"$CA_BUNDLE\"}]"

echo "✅ Webhook CA bundle fixed!"
echo ""
echo "Verifying..."
kubectl get validatingwebhookconfiguration ingress-nginx-admission -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | wc -c | xargs -I {} echo "CA bundle length: {} bytes"
