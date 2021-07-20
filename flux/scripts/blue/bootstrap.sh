#!/bin/bash

# Before running this script, you must:
# export GITHUB_TOKEN=your-token
# export GITHUB_USER=your-username

AKS_RESOURCE_GROUP=your-resource-group-blue
AKS_CLUSTER_NAME=your-aks-cluster-name-blue
BG_SWITCH=blue


az aks get-credentials -g ${AKS_RESOURCE_GROUP} -n ${AKS_CLUSTER_NAME} --admin --overwrite-existing

flux bootstrap github \
  --owner=${GITHUB_USER} \
  --repository=aks-safe-deploy \
  --branch=main \
  --path=./flux/clusters/${BG_SWITCH} \
  --personal
