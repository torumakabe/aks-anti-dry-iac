terraform {
  required_version = "~> 1.0.9"
  backend "remote" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.81.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "shared" {
  name     = var.shared_rg.name
  location = var.shared_rg.location
}

resource "azurerm_virtual_network" "default" {
  name                = "vnet-default"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  address_space       = ["10.0.0.0/8"]
}

resource "azurerm_subnet" "aks_pod_shared" {
  name                 = "snet-aks-pod-shared"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.0.0.0/16"]

  delegation {
    name = "aks-delegation"

    service_delegation {
      name    = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

// Reserved ranges
// 10.1.0.0/20 for AKS Service (Blue)
// 10.1.16.0/20 for AKS Service (Green)

resource "azurerm_subnet" "aks_blue" {
  name                 = "snet-aks-blue"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.1.32.0/24"]
}

resource "azurerm_subnet" "aks_blue_svc_lb" {
  name                 = "snet-aks-blue-svc-lb"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.1.33.0/24"]

}

resource "azurerm_subnet" "aks_green" {
  name                 = "snet-aks-green"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.1.34.0/24"]
}

resource "azurerm_subnet" "aks_green_svc_lb" {
  name                 = "snet-aks-green-svc-lb"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.1.35.0/24"]
}

resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.1.36.0/24"]
}

resource "azurerm_subnet" "endpoint" {
  name                                           = "snet-endpoint"
  resource_group_name                            = azurerm_resource_group.shared.name
  virtual_network_name                           = azurerm_virtual_network.default.name
  address_prefixes                               = ["10.1.37.0/24"]
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_subnet" "aci" {
  name                 = "snet-aci"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.1.38.0/24"]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_network_profile" "aci_demoapp_redis" {
  name                = "nwprof-aci-demoapp-redis"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name

  container_network_interface {
    name = "nic-aci-demoapp-redis"

    ip_configuration {
      name      = "ipconf-aci-demoapp-redis"
      subnet_id = azurerm_subnet.aci.id
    }
  }
}

resource "azurerm_public_ip" "demoapp" {
  name                = "pip-demoapp"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "shared" {
  name                = local.agw_name
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = local.agw_settings.gateway_ip_configuration_name
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = local.agw_settings.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.agw_settings.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.demoapp.id
  }

  backend_address_pool {
    name         = local.agw_settings.backend_address_pool_name
    ip_addresses = local.agw_settings.backend_ip_addresses
  }

  backend_http_settings {
    name                  = local.agw_settings.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 10
    connection_draining {
      enabled           = true
      drain_timeout_sec = 10
    }
  }

  http_listener {
    name                           = local.agw_settings.listener_name
    frontend_ip_configuration_name = local.agw_settings.frontend_ip_configuration_name
    frontend_port_name             = local.agw_settings.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.agw_settings.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.agw_settings.listener_name
    backend_address_pool_name  = local.agw_settings.backend_address_pool_name
    backend_http_settings_name = local.agw_settings.http_setting_name
  }
}

resource "random_password" "redis_password" {
  length  = 16
  special = true
}

# recommend to use managed redis for production
resource "azurerm_container_group" "demoapp_redis" {
  name                = "ci-demoapp-redis"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  ip_address_type     = "Private"
  network_profile_id  = azurerm_network_profile.aci_demoapp_redis.id
  exposed_port {
    port     = 6379
    protocol = "TCP"
  }
  restart_policy = "Always"
  os_type        = "Linux"

  container {
    name   = "redis"
    image  = "bitnami/redis:6.2.4"
    cpu    = "1.0"
    memory = "1.0"

    ports {
      port     = 6379
      protocol = "TCP"
    }

    environment_variables = {
      "REDIS_PASSWORD" = random_password.redis_password.result
    }
  }
}


resource "azurerm_private_dns_zone" "demoapp_shared" {
  name                = "demoapp.io"
  resource_group_name = azurerm_resource_group.shared.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "demoapp_shared" {
  name                  = "pdnsz-link-demoapp-shared"
  resource_group_name   = azurerm_resource_group.shared.name
  private_dns_zone_name = azurerm_private_dns_zone.demoapp_shared.name
  virtual_network_id    = azurerm_virtual_network.default.id
}

resource "azurerm_private_dns_a_record" "demoapp_redis" {
  name                = "redis"
  zone_name           = azurerm_private_dns_zone.demoapp_shared.name
  resource_group_name = azurerm_resource_group.shared.name
  ttl                 = 300
  records             = [azurerm_container_group.demoapp_redis.ip_address]
}

resource "azurerm_key_vault" "demoapp" {
  name                = "${var.prefix}-kv-demoapp"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
}

resource "azurerm_key_vault_access_policy" "demoapp_admin" {
  key_vault_id = azurerm_key_vault.demoapp.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "backup",
    "delete",
    "get",
    "list",
    "purge",
    "recover",
    "restore",
    "set",
  ]

  # for CI
  lifecycle {
    ignore_changes = [
      object_id,
    ]
  }
}

resource "azurerm_key_vault_secret" "demoapp_redis_server" {
  depends_on = [
    azurerm_key_vault_access_policy.demoapp_admin
  ]
  name         = "redis-server"
  value        = "${azurerm_private_dns_a_record.demoapp_redis.fqdn}:6379"
  key_vault_id = azurerm_key_vault.demoapp.id
}

resource "azurerm_key_vault_secret" "demoapp_redis_password" {
  depends_on = [
    azurerm_key_vault_access_policy.demoapp_admin
  ]
  name         = "redis-password"
  value        = random_password.redis_password.result
  key_vault_id = azurerm_key_vault.demoapp.id
}


resource "azurerm_private_dns_zone" "demoapp_kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.shared.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "demoapp_kv" {
  name                  = "pdnsz-link-demoapp-kv"
  resource_group_name   = azurerm_resource_group.shared.name
  private_dns_zone_name = azurerm_private_dns_zone.demoapp_kv.name
  virtual_network_id    = azurerm_virtual_network.default.id
}

resource "azurerm_private_endpoint" "demoapp_kv" {
  name                = "pe-demoapp-kv"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  subnet_id           = azurerm_subnet.endpoint.id

  private_dns_zone_group {
    name                 = "pdnsz-group-demoapp-kv"
    private_dns_zone_ids = [azurerm_private_dns_zone.demoapp_kv.id]
  }

  private_service_connection {
    name                           = "pe-connection-demoapp-kv"
    private_connection_resource_id = azurerm_key_vault.demoapp.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
}
