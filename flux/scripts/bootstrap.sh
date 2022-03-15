#!/usr/bin/env bash
set -eo pipefail

# Before running this script, you must:
# export GITHUB_TOKEN=your-token
# export GITHUB_USER=your-username

if [ $# -lt 3 ] && [ $# -gt 4 ]
then
  echo "[Error] Usage: bootstrap.sh <blue/green> <cluster resource group name> <cluster name> <flux branch(defaut: main)>"
  exit 1
fi

if [ "$1" != "blue" ] && [ "$1" != "green" ]
then
  echo "[Error] Usage: bootstrap.sh <blue/green> <cluster resource group name> <cluster name>"
  exit 1
fi

CLUSTER_SWITCH=$1
AKS_RESOURCE_GROUP_NAME=$2
AKS_CLUSTER_NAME=$3
FLUX_BRANCH=${4:-main}

export KUBECONFIG=${HOME}/.kube/config-flux-${AKS_CLUSTER_NAME}

az aks get-credentials -g "${AKS_RESOURCE_GROUP_NAME}" -n "${AKS_CLUSTER_NAME}" -f "${KUBECONFIG}" --overwrite-existing

kubelogin convert-kubeconfig -l azurecli

flux bootstrap github \
  --owner="${GITHUB_USER}" \
  --repository=aks-anti-dry-iac \
  --branch="${FLUX_BRANCH}" \
  --path="./flux/clusters/${CLUSTER_SWITCH}" \
  --personal \
  --toleration-keys=CriticalAddonsOnly
