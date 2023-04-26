locals {
  tenant_id = data.azurerm_client_config.current.tenant_id
  current_client = {
    subscription_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
    object_id       = data.azurerm_client_config.current.object_id
  }
  shared_rg = {
    name     = "rg-aks-anti-dry-iac-shared-${var.suffix}"
    location = var.shared_rg.location
  }
  subnet_addrs = {
    base_cidr_block = "10.1.0.0/16"
  }
  agw_name = "agw-shared" # separate from settings to avoid self-referencing local value
  agw_settings = {
    gateway_ip_configuration_name  = "${local.agw_name}-gwip"
    frontend_port_name             = "${local.agw_name}-feport"
    frontend_ip_configuration_name = "${local.agw_name}-feip"
  }
  demoapp = {
    agw_settings = {
      listener_name               = "demoapp-httplstn"
      backend_address_pool_name   = "demoapp-beap"
      http_setting_name           = "demoapp-be-htst"
      request_routing_rule_name   = "demoapp-rqrt"
      url_path_map_name           = "demoapp-urlpmn"
      redirect_configuration_name = "demoapp-rdcfg"
      probe_name                  = "demoapp-probe"
    }
    key_vault = {
      name = "${var.prefix}-kv-demoapp-${var.suffix}"
      // add as needed
      ip_rules = [
        chomp(data.http.my_public_ip.response_body)
      ]
    }
  }
}

data "azurerm_client_config" "current" {}

data "http" "my_public_ip" {
  url = "https://ipconfig.io"
}
