#!/usr/bin/env bash
set -eo pipefail

USAGE="[Error] Usage: cleanup.sh <cluster resource group name> <cluster name> <chaos manifest YAML file path>"

if [ $# -lt 2 ] || [ $# -gt 3 ]
then
  echo "$USAGE"
  exit 1
fi

AKS_RESOURCE_GROUP_NAME=$1
AKS_CLUSTER_NAME=$2
MANIFEST_FILE_PATH=$3

export KUBECONFIG=${HOME}/.kube/config-chaos-${AKS_CLUSTER_NAME}

az aks get-credentials -g "${AKS_RESOURCE_GROUP_NAME}" -n "${AKS_CLUSTER_NAME}" -f "${KUBECONFIG}" --overwrite-existing

kubelogin convert-kubeconfig -l azurecli

kubectl delete -f "${MANIFEST_FILE_PATH}"

rm "${KUBECONFIG}"
