# If you don't want to manage with files, choose other means such as environment variables.
# https://www.terraform.io/docs/language/values/variables.html

prefix = "your-prefix"
aks_rg = {
  name     = "rg-aks-anti-dry-blue"
  location = "japaneast"
}
aks_network = {
  subnet_id        = "/subscriptions/your-subscription-id/resourceGroups/rg-aks-anti-dry-shared/providers/Microsoft.Network/virtualNetworks/vnet-default/subnets/snet-aks-blue"
  subnet_svc_lb_id = "/subscriptions/your-subscription-id/resourceGroups/rg-aks-anti-dry-shared/providers/Microsoft.Network/virtualNetworks/vnet-default/subnets/snet-aks-blue-svc-lb"
}
log_analytics = {
  workspace_id = "/subscriptions/your-subscription-id/resourcegroups/defaultresourcegroup-ejp/providers/microsoft.operationalinsights/workspaces/defaultworkspace-your-subscription-id-ejp"
}
demoapp = {
  key_vault_id = "/subscriptions/your-subscription-id/resourceGroups/rg-aks-anti-dry-shared/providers/Microsoft.KeyVault/vaults/your-prefix-kv-demoapp"
}
# Optional: If you need to run 'terraform plan' for exsiting AKS cluster in CI. (Non-immutable)
# ci_sp_oid = "your-service-principal-object-id-for-ci"
