locals {
  tenant_id      = data.azurerm_client_config.current.tenant_id
  subnet_id_base = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.shared_rg.name}/providers/Microsoft.Network/virtualNetworks/vnet-default/subnets"
  shared_rg = {
    name = "rg-aks-anti-dry-iac-shared-${var.suffix}"
  }
  aks = {
    rg = {
      name     = "rg-aks-anti-dry-iac-${var.aks.switch}-${var.suffix}"
      location = var.aks.rg.location
    }
    cluster_name = "${var.prefix}-aks-anti-dry-iac-${var.aks.switch}-${var.suffix}"
    default = {
      orchestrator_version = "1.25.4"
      vm_size              = "Standard_D2ds_v5"
      os_disk_size_gb      = 30
      os_disk_type         = "Ephemeral"
      os_sku               = "Ubuntu"
    }
    network = {
      node_system_subnet_id         = "${local.subnet_id_base}/snet-aks-${var.aks.switch}-node-system"
      node_user_az_subnet_id_prefix = "${local.subnet_id_base}/snet-aks-${var.aks.switch}-node-user-az"
      pod_subnet_id                 = "${local.subnet_id_base}/snet-aks-pod-shared"
      svc_lb_subnet_id              = "${local.subnet_id_base}/snet-aks-${var.aks.switch}-svc-lb"
    }
  }
  log_analytics = {
    workspace_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.log_analytics.workspace.rg_name}/providers/Microsoft.OperationalInsights/workspaces/${var.log_analytics.workspace.name}"
  }
  demoapp = {
    service_account = {
      name      = "demoapp-sa"
      namespace = "demoapp"
    }
    key_vault = {
      name = "${var.prefix}-${var.demoapp.key_vault.name_body}-${var.suffix}"
      id   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.shared_rg.name}/providers/Microsoft.KeyVault/vaults/${var.prefix}-${var.demoapp.key_vault.name_body}-${var.suffix}" # repeat key vault name interpolation to avoid self-referencing local value
    }
  }
}

data "azurerm_client_config" "current" {}

data "http" "my_public_ip" {
  url = "https://ipconfig.io"
}
