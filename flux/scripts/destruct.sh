#!/usr/bin/env bash
set -eo pipefail

if [ $# != 2 ]
then
  echo "[Error] Usage: descturt.sh <cluster resource group name> <cluster name>"
  exit 1
fi

AKS_RESOURCE_GROUP_NAME=$1
AKS_CLUSTER_NAME=$2

export KUBECONFIG=${HOME}/.kube/config-flux-${AKS_CLUSTER_NAME}

az aks get-credentials -g "${AKS_RESOURCE_GROUP_NAME}" -n "${AKS_CLUSTER_NAME}" -f "${KUBECONFIG}" --overwrite-existing

kubelogin convert-kubeconfig -l azurecli

flux delete kustomization apps -s
flux delete kustomization infrastructure -s
flux uninstall -s

rm "${KUBECONFIG}"
