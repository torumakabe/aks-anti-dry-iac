#!/usr/bin/env bash
set -eo pipefail

# Before running this script, you must:
# export GITHUB_TOKEN=your-token
# export GITHUB_USER=your-username

if [ $# != 3 ]
then
  echo "[Error] Usage: bootstrap.sh <blue/green> <cluster resource group name> <cluster name>"
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

az aks get-credentials -g "${AKS_RESOURCE_GROUP_NAME}" -n "${AKS_CLUSTER_NAME}" --admin --overwrite-existing

flux bootstrap github \
  --owner="${GITHUB_USER}" \
  --repository=aks-playground \
  --branch=main \
  --path="./flux/clusters/${CLUSTER_SWITCH}" \
  --personal
