#!/usr/bin/env bash
# Tear down the local kind cluster. Wipes all in-cluster Postgres data.

set -euo pipefail

CLUSTER_NAME="feedforge-local"

if kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  echo "==> Deleting kind cluster '${CLUSTER_NAME}'"
  kind delete cluster --name "${CLUSTER_NAME}"
else
  echo "==> No cluster named '${CLUSTER_NAME}' to delete"
fi
