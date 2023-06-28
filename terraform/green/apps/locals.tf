locals {
  tenant_id = data.azurerm_client_config.current.tenant_id

  demoapp = {
    service_account = {
      name      = "demoapp-sa"
      namespace = "demoapp"
    }
  }
}

data "azurerm_client_config" "current" {}
