#!/bin/sh
set -eu

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "Waiting for k3s API server to become ready..."
max_attempts=60
attempt=0
until /usr/bin/kubectl get nodes >/dev/null 2>&1 || [ "$attempt" -ge "$max_attempts" ]; do
    attempt=$((attempt + 1))
    sleep 2
done

if [ "$attempt" -ge "$max_attempts" ]; then
    echo "Timed out waiting for k3s API server."
    exit 1
fi

echo "k3s is ready. Deploying Trustee Helm release..."
HELM_DEPLOY_ARGS=("/usr/share/trustee-helm/chart")
if [ -s /usr/share/trustee-helm/values.yaml ]; then
    HELM_DEPLOY_ARGS+=("-f" "/usr/share/trustee-helm/values.yaml")
fi

/usr/bin/helm upgrade --install trustee "${HELM_DEPLOY_ARGS[@]}" \
    --namespace coco-trustee \
    --create-namespace \
    --wait \
    --timeout 3m

echo "Trustee stack deployed successfully."
