#!/usr/bin/env bash
set -eo pipefail

AKS_RESOURCE_GROUP_NAME=$1
AKS_CLUSTER_NAME=$2
TENANT_ID=$3
MI_DEMOAPP=$4
DEMOAPP_KEY_VAULT_NAME=$5
DEMOAPP_INGRESS_SVC_SUBNET=$6
DEMOAPP_INGRESS_SVC_IP=$7

export KUBECONFIG=${HOME}/.kube/config-flux-${AKS_CLUSTER_NAME}

az aks get-credentials -g "${AKS_RESOURCE_GROUP_NAME}" -n "${AKS_CLUSTER_NAME}" -f "${KUBECONFIG}" --overwrite-existing

kubelogin convert-kubeconfig -l azurecli

cat <<EOT | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: flux-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: flux-configs
  namespace: flux-system
data:
  tenant_id: ${TENANT_ID}
  mi_demoapp: ${MI_DEMOAPP}
  demoapp_key_vault_name: ${DEMOAPP_KEY_VAULT_NAME}
  demoapp_ingress_svc_subnet: ${DEMOAPP_INGRESS_SVC_SUBNET}
  demoapp_ingress_svc_ip: ${DEMOAPP_INGRESS_SVC_IP}
EOT
