#!/usr/bin/env bash
set -eo pipefail

if [ $# != 2 ]
then
  echo "[Error] Usage: usecontext.sh <cluster resource group name> <cluster name>"
  exit 1
fi

AKS_RESOURCE_GROUP_NAME=$1
AKS_CLUSTER_NAME=$2

az aks get-credentials -g "${AKS_RESOURCE_GROUP_NAME}" -n "${AKS_CLUSTER_NAME}" --admin --overwrite-existing

kubectl config use-context "${AKS_CLUSTER_NAME}-admin"
