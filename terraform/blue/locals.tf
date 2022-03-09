locals {
  shared_rg = {
    name = "rg-aks-anti-dry-iac-shared-${var.suffix}"
  }
  aks = {
    rg = {
      name     = "rg-aks-anti-dry-iac-${var.aks.switch}-${var.suffix}"
      location = var.aks.rg.location
    }
    cluster_name = "${var.prefix}-aks-anti-dry-iac-${var.aks.switch}-${var.suffix}"
  }
  log_analytics = {
    workspace_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.log_analytics.workspace.rg_name}/providers/Microsoft.OperationalInsights/workspaces/${var.log_analytics.workspace.name}"
  }
  demoapp = {
    key_vault = {
      name = "${var.prefix}-${var.demoapp.key_vault.name_body}-${var.suffix}"
      id   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.shared_rg.name}/providers/Microsoft.KeyVault/vaults/${var.prefix}-${var.demoapp.key_vault.name_body}-${var.suffix}" # repeat key vault name interpolation to avoid self-referencing local value
    }
  }
}

data "azurerm_client_config" "current" {}
