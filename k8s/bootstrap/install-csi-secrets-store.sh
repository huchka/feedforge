#!/usr/bin/env bash
# install-csi-secrets-store.sh — Install the Secrets Store CSI Driver and GCP provider.
#
# Idempotent: safe to re-run (uses helm upgrade --install).
# Requires: helm 3, kubectl configured for the target cluster.
#
# See docs/secret-manager.md for full architecture details.

set -euo pipefail

# --- Secrets Store CSI Driver (Helm) ---
# Deploys the DaemonSet that mounts external secrets as volumes in pods.
# syncSecret.enabled=true allows the driver to sync mounted secrets into
# native Kubernetes Secret objects (used by secretObjects in SecretProviderClass).

helm repo add secrets-store-csi-driver \
  https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update secrets-store-csi-driver

helm upgrade --install csi-secrets-store \
  secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system \
  --set syncSecret.enabled=true \
  --wait

echo "Secrets Store CSI Driver installed."

# --- GCP Provider ---
# The provider plugin runs as a DaemonSet and handles communication with
# GCP Secret Manager on behalf of the CSI driver.

kubectl apply -f \
  https://raw.githubusercontent.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp/main/deploy/provider-gcp-plugin.yaml

echo "GCP provider for Secrets Store CSI Driver installed."

# --- Verification ---
echo "Verifying pods are running..."
kubectl wait --for=condition=ready pod \
  -l app=secrets-store-csi-driver \
  -n kube-system \
  --timeout=120s

echo "CSI Secrets Store installation complete."
