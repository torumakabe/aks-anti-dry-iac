#!/usr/bin/env bash
set -eo pipefail

# Before running this script, you must:
# export GITHUB_TOKEN=your-token
# export GITHUB_USER=your-username

if [ $# -lt 4 ] && [ $# -gt 5 ]
then
  echo "[Error] Usage: setup-flux.sh <blue/green> <cluster resource group name> <cluster name> <flux repo url> <flux branch(defaut: main)>"
  exit 1
fi

if [ "$1" != "blue" ] && [ "$1" != "green" ]
then
  echo "[Error] Usage: setup-flux.sh <blue/green> <cluster resource group name> <cluster name> <flux repo url> <flux branch(defaut: main)>"
  exit 1
fi

CLUSTER_SWITCH=$1
AKS_RESOURCE_GROUP_NAME=$2
AKS_CLUSTER_NAME=$3
FLUX_REPO_URL=$4
FLUX_BRANCH=${5:-main}

export KUBECONFIG=${HOME}/.kube/config-flux-${AKS_CLUSTER_NAME}

az aks get-credentials -g "${AKS_RESOURCE_GROUP_NAME}" -n "${AKS_CLUSTER_NAME}" -f "${KUBECONFIG}" --overwrite-existing

kubelogin convert-kubeconfig -l azurecli

flux install --log-level debug

flux create secret git github-credentials \
  --url="${FLUX_REPO_URL}" \
  --username="${GITHUB_USER}" \
  --password="${GITHUB_TOKEN}"

kubectl apply -f - <<EOF
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 15m
  ref:
    branch: ${FLUX_BRANCH}
  url: ${FLUX_REPO_URL}
  secretRef:
    name: github-credentials
  ignore: |
    /flux/clusters/${CLUSTER_SWITCH}/flux-system/
EOF

flux create kustomization flux-system \
  --interval=15m \
  --source=flux-system \
  --path="./flux/clusters/${CLUSTER_SWITCH}"
