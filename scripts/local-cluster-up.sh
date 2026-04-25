#!/usr/bin/env bash
# Bootstrap a local kind cluster with Calico CNI and CloudNativePG operator.
# Idempotent: safe to re-run.
#
# Prereqs: kind, kubectl, skaffold, docker (or compatible runtime).

set -euo pipefail

CLUSTER_NAME="feedforge-local"
CALICO_VERSION="v3.28.2"
CNPG_VERSION="1.24.1"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KIND_CONFIG="${REPO_ROOT}/k8s/local/kind-config.yaml"

echo "==> Checking required tools"
for cmd in kind kubectl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required tool: $cmd"; exit 1; }
done

if kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  echo "==> Cluster '${CLUSTER_NAME}' already exists"
else
  echo "==> Creating kind cluster '${CLUSTER_NAME}'"
  kind create cluster --config "${KIND_CONFIG}"
fi

kubectl config use-context "kind-${CLUSTER_NAME}"

echo "==> Installing Calico CNI (${CALICO_VERSION})"
kubectl apply --server-side -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"

echo "==> Waiting for Calico to be ready (this takes a minute)"
kubectl -n calico-system wait --for=condition=Ready pods --all --timeout=300s || {
  echo "Calico pods not ready yet — check 'kubectl -n calico-system get pods'"
  exit 1
}

echo "==> Installing CloudNativePG operator (${CNPG_VERSION})"
kubectl apply --server-side -f "https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-${CNPG_VERSION}.yaml"
kubectl -n cnpg-system wait --for=condition=Available deployment/cnpg-controller-manager --timeout=180s

echo "==> Cluster ready. Next:"
echo "    skaffold run -p local      # build + deploy"
echo "    skaffold dev -p local      # build + deploy + watch"
