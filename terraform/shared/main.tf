terraform {
  required_version = "~> 1.2.4"
  # Choose the backend according to your requirements
  # backend "remote" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.12.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.3"
    }
  }
}

module "subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = local.subnet_addrs.base_cidr_block
  networks = [
    {
      name     = "aks_pod_shared"
      new_bits = 2
    },
    {
      name     = "aks_blue_node_system"
      new_bits = 8
    },
    {
      name     = "aks_blue_node_user_az1"
      new_bits = 8
    },
    {
      name     = "aks_blue_node_user_az2"
      new_bits = 8
    },
    {
      name     = "aks_blue_node_user_az3"
      new_bits = 8
    },
    {
      name     = "aks_blue_svc_lb"
      new_bits = 8
    },
    {
      name     = "aks_green_node_system"
      new_bits = 8
    },
    {
      name     = "aks_green_node_user_az1"
      new_bits = 8
    },
    {
      name     = "aks_green_node_user_az2"
      new_bits = 8
    },
    {
      name     = "aks_green_node_user_az3"
      new_bits = 8
    },
    {
      name     = "aks_green_svc_lb"
      new_bits = 8
    },
    {
      name     = "appgw"
      new_bits = 8
    },
    {
      name     = "endpoint"
      new_bits = 8
    },
    {
      name     = "aci"
      new_bits = 8
    },
  ]
}

provider "azurerm" {
  use_oidc = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "shared" {
  name     = local.shared_rg.name
  location = local.shared_rg.location
}

resource "azurerm_virtual_network" "default" {
  name                = "vnet-default"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  address_space       = [module.subnet_addrs.base_cidr_block]
}

resource "azurerm_subnet" "aks_pod_shared" {
  name                 = "snet-aks-pod-shared"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = [module.subnet_addrs.network_cidr_blocks["aks_pod_shared"]]

  delegation {
    name = "aks-delegation"

    service_delegation {
      name    = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "aks_blue_node_system" {
  name                 = "snet-aks-blue-node-system"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = [module.subnet_addrs.network_cidr_blocks["aks_blue_node_system"]]
}

resource "azurerm_subnet" "aks_blue_node_user_az" {
  for_each             = toset(["1", "2", "3"])
  name                 = "snet-aks-blue-node-user-az${each.key}"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = [module.subnet_addrs.network_cidr_blocks["aks_blue_node_user_az${each.key}"]]
}

resource "azurerm_subnet" "aks_blue_svc_lb" {
  name                 = "snet-aks-blue-svc-lb"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = [module.subnet_addrs.network_cidr_blocks["aks_blue_svc_lb"]]

}

resource "azurerm_subnet" "aks_green_node_system" {
  name                 = "snet-aks-green-node-system"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = [module.subnet_addrs.network_cidr_blocks["aks_green_node_system"]]
}

resource "azurerm_subnet" "aks_green_node_user_az" {
  for_each             = toset(["1", "2", "3"])
  name                 = "snet-aks-green-node-user-az${each.key}"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = [module.subnet_addrs.network_cidr_blocks["aks_green_node_user_az${each.key}"]]
}

resource "azurerm_subnet" "aks_green_svc_lb" {
  name                 = "snet-aks-green-svc-lb"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = [module.subnet_addrs.network_cidr_blocks["aks_green_svc_lb"]]
}

resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = [module.subnet_addrs.network_cidr_blocks["appgw"]]
}

resource "azurerm_subnet" "endpoint" {
  name                                           = "snet-endpoint"
  resource_group_name                            = azurerm_resource_group.shared.name
  virtual_network_name                           = azurerm_virtual_network.default.name
  address_prefixes                               = [module.subnet_addrs.network_cidr_blocks["endpoint"]]
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_subnet" "aci" {
  name                 = "snet-aci"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = [module.subnet_addrs.network_cidr_blocks["aci"]]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

  // Waiting for delegation
  provisioner "local-exec" {
    command = "sleep 30"
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
  zones               = [1, 2, 3]
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

  zones = [1, 2, 3]

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
    name         = local.demoapp.agw_settings.backend_address_pool_name
    ip_addresses = local.demoapp.agw_settings.backend_ip_addresses
  }

  backend_http_settings {
    name                  = local.demoapp.agw_settings.http_setting_name
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
    name                           = local.demoapp.agw_settings.listener_name
    frontend_ip_configuration_name = local.agw_settings.frontend_ip_configuration_name
    frontend_port_name             = local.agw_settings.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.demoapp.agw_settings.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.demoapp.agw_settings.listener_name
    backend_address_pool_name  = local.demoapp.agw_settings.backend_address_pool_name
    backend_http_settings_name = local.demoapp.agw_settings.http_setting_name
    priority                   = 100
  }
}

resource "azurerm_public_ip_prefix" "nat_outbound_aks_blue_user_az" {
  for_each            = toset(["1", "2", "3"])
  name                = "ippre-nat-outbound-aks-blue-az${each.key}"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  prefix_length       = 30
  zones               = [each.key]
}

resource "azurerm_nat_gateway" "aks_blue_user_az" {
  for_each            = toset(["1", "2", "3"])
  name                = "ng-aks-blue-user-az${each.key}"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_prefix_association" "aks_blue_user_az" {
  for_each            = toset(["1", "2", "3"])
  nat_gateway_id      = azurerm_nat_gateway.aks_blue_user_az[each.key].id
  public_ip_prefix_id = azurerm_public_ip_prefix.nat_outbound_aks_blue_user_az[each.key].id
}

resource "azurerm_subnet_nat_gateway_association" "aks_blue_user_az" {
  for_each       = toset(["1", "2", "3"])
  subnet_id      = azurerm_subnet.aks_blue_node_user_az[each.key].id
  nat_gateway_id = azurerm_nat_gateway.aks_blue_user_az[each.key].id
}

resource "azurerm_public_ip_prefix" "nat_outbound_aks_green_user_az" {
  for_each            = toset(["1", "2", "3"])
  name                = "ippre-nat-outbound-aks-green-az${each.key}"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  prefix_length       = 30
  zones               = [each.key]
}

resource "azurerm_nat_gateway" "aks_green_user_az" {
  for_each            = toset(["1", "2", "3"])
  name                = "ng-aks-green-user-az${each.key}"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_prefix_association" "aks_green_user_az" {
  for_each            = toset(["1", "2", "3"])
  nat_gateway_id      = azurerm_nat_gateway.aks_green_user_az[each.key].id
  public_ip_prefix_id = azurerm_public_ip_prefix.nat_outbound_aks_green_user_az[each.key].id
}

resource "azurerm_subnet_nat_gateway_association" "aks_green_user_az" {
  for_each       = toset(["1", "2", "3"])
  subnet_id      = azurerm_subnet.aks_green_node_user_az[each.key].id
  nat_gateway_id = azurerm_nat_gateway.aks_green_user_az[each.key].id
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
    image  = "bitnami/redis:7.0.2"
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
  name                = local.demoapp.key_vault.name
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  tenant_id           = local.tenant_id
  sku_name            = "standard"

  /* If you could exec Terraform in private network can reach kv private endpoint
  network_acls {
    bypass         = "None"
    default_action = "Deny"
  }
  */
}

resource "azurerm_key_vault_access_policy" "demoapp_admin" {
  key_vault_id = azurerm_key_vault.demoapp.id
  tenant_id    = local.tenant_id
  object_id    = local.current_client.object_id

  secret_permissions = [
    "Backup",
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Set",
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

/* Just a sample of Azure Policy assignment. It is recommended to assign it in the management group to take advantage of inheritance and avoid duplicate assignments in the subscription.

data "azurerm_policy_definition" "k8s_container_no_privilege" {
  name = "95edb821-ddaf-4404-9732-666045e056b4"
}

resource "azurerm_subscription_policy_assignment" "k8s_container_no_privilege" {
  name                 = "k8s-container-no-privilege"
  policy_definition_id = data.azurerm_policy_definition.k8s_container_no_privilege.id
  subscription_id      = local.current_client.subscription_id

  parameters = <<PARAMETERS
    {
      "effect": {
        "value": "deny"
      },
      "excludedNamespaces": {
        "value":
        [
          "kube-system",
          "gatekeeper-system",
          "chaos-testing",
          "azure-arc"
        ]
      },
      "namespaces": {
        "value": []
      },
      "labelSelector": {
        "value": {}
      },
      "excludedContainers": {
        "value": []
      }
    }
PARAMETERS
}
*/
