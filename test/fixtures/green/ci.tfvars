# If you don't want to manage with files, choose other means such as environment variables.
# https://www.terraform.io/docs/language/values/variables.html

prefix = "your-prefix"
aks_rg = {
  name     = "rg-aks-anti-dry-green-ci"
  location = "japaneast"
}
aks_network = {
  pod_subnet_id    = "/subscriptions/your-subscription-id/resourceGroups/rg-aks-anti-dry-shared-ci/providers/Microsoft.Network/virtualNetworks/vnet-default/subnets/snet-aks-pod-shared"
  subnet_id        = "/subscriptions/your-subscription-id/resourceGroups/rg-aks-anti-dry-shared-ci/providers/Microsoft.Network/virtualNetworks/vnet-default/subnets/snet-aks-blue"
  subnet_svc_lb_id = "/subscriptions/your-subscription-id/resourceGroups/rg-aks-anti-dry-shared-ci/providers/Microsoft.Network/virtualNetworks/vnet-default/subnets/snet-aks-blue-svc-lb"
}
log_analytics = {
  workspace_id = "/subscriptions/your-subscription-id/resourcegroups/rg-your-log-analytics/providers/microsoft.operationalinsights/workspaces/your-workspace"
}
demoapp = {
  key_vault_id = "/subscriptions/your-subscription-id/resourceGroups/rg-aks-anti-dry-shared-ci/providers/Microsoft.KeyVault/vaults/your-prefix-kv-demoapp"
}
