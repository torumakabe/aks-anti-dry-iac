#!/bin/bash
set -eo pipefail

eval "$(jq -r '@sh "RG_NAME=\(.rg_name) CLUSTER_NAME=\(.cluster_name)"')"

az aks get-credentials -g "${RG_NAME}" -n "${CLUSTER_NAME}" --file ./tmpconfig

SERVER=$(yq '.clusters[0].cluster.server' ./tmpconfig)
CERT_AUTH_DATA=$(yq '.clusters[0].cluster.certificate-authority-data' ./tmpconfig)

rm ./tmpconfig

jq -n --arg server "${SERVER}" --arg cert_auth_data "${CERT_AUTH_DATA}" '{"server":$server, "cert_auth_data":$cert_auth_data}'
