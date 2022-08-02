terraform {
  required_version = "~> 1.2.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.16.0"
    }
  }
}

resource "azurerm_resource_group" "aks" {
  name     = local.aks.rg.name
  location = local.aks.rg.location
}

# Optional: To keep up with the latest version
/*
data "azurerm_kubernetes_service_versions" "current" {
  location        = azurerm_resource_group.aks.location
  version_prefix  = "1.23"
  include_preview = false
}
*/

resource "azurerm_user_assigned_identity" "aks_cplane" {
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  name                = "mi-aks-cplane"
}

resource "azurerm_user_assigned_identity" "aks_kubelet" {
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  name                = "mi-aks-kubelet"
}

resource "azurerm_role_assignment" "aks_mi_operator" {
  scope                = azurerm_resource_group.aks.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.aks_cplane.principal_id


  // Waiting for Azure AD preparation
  provisioner "local-exec" {
    command = "sleep 30"
  }
}

resource "azurerm_role_assignment" "aks_node_subnet_system" {
  scope                = local.aks.network.node_system_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_cplane.principal_id

  // Waiting for Azure AD preparation
  provisioner "local-exec" {
    command = "sleep 30"
  }
}

resource "azurerm_role_assignment" "aks_node_subnet_az" {
  for_each             = toset(["1", "2", "3"])
  scope                = "${local.aks.network.node_user_az_subnet_id_prefix}${each.key}"
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_cplane.principal_id

  // Waiting for Azure AD preparation
  provisioner "local-exec" {
    command = "sleep 30"
  }
}

resource "azurerm_role_assignment" "aks_subnet_svc_lb" {
  scope                = local.aks.network.svc_lb_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_cplane.principal_id

  // Waiting for Azure AD preparation
  provisioner "local-exec" {
    command = "sleep 30"
  }
}


resource "azurerm_kubernetes_cluster" "default" {
  depends_on = [
    azurerm_role_assignment.aks_mi_operator,
    azurerm_role_assignment.aks_node_subnet_system,
    azurerm_role_assignment.aks_subnet_svc_lb,
  ]
  name = local.aks.cluster_name
  # Optional: To keep up with the latest version
  # kubernetes_version  = data.azurerm_kubernetes_service_versions.current.latest_version
  kubernetes_version     = local.aks.default.orchestrator_version
  location               = azurerm_resource_group.aks.location
  resource_group_name    = azurerm_resource_group.aks.name
  node_resource_group    = "${azurerm_resource_group.aks.name}-node"
  dns_prefix             = local.aks.cluster_name
  sku_tier               = "Paid"
  local_account_disabled = true

  default_node_pool {
    name = "system"
    type = "VirtualMachineScaleSets"
    # Optional: To keep up with the latest version
    # orchestrator_version  = data.azurerm_kubernetes_service_versions.current.latest_version
    orchestrator_version         = local.aks.default.orchestrator_version
    vnet_subnet_id               = local.aks.network.node_system_subnet_id
    pod_subnet_id                = local.aks.network.pod_subnet_id
    zones                        = [1, 2, 3]
    node_count                   = var.aks.node_pool.system.node_count
    vm_size                      = local.aks.default.vm_size
    only_critical_addons_enabled = true

    os_disk_size_gb = local.aks.default.os_disk_size_gb
    os_disk_type    = local.aks.default.os_disk_type
    os_sku          = local.aks.default.os_sku
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_cplane.id]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.aks_kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.aks_kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.aks_kubelet.id
  }

  role_based_access_control_enabled = true
  azure_active_directory_role_based_access_control {
    managed                = true
    admin_group_object_ids = var.aks.aad.admin_group_object_ids
    azure_rbac_enabled     = true
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
    network_mode   = "transparent"
    service_cidr   = "10.0.0.0/16"
    dns_service_ip = "10.0.0.10"
    // Unnecessary it now practically, but for passing validation of terraform
    docker_bridge_cidr = "172.17.0.1/16"

    load_balancer_sku = "standard"
    load_balancer_profile {
      managed_outbound_ip_count = 1
    }
  }

  azure_policy_enabled = true
  oms_agent {
    log_analytics_workspace_id = local.log_analytics.workspace_id
  }
  open_service_mesh_enabled = false
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_labels,
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each              = toset(["1", "2", "3"])
  name                  = "az${each.key}"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.default.id
  orchestrator_version  = local.aks.default.orchestrator_version
  vnet_subnet_id        = "${local.aks.network.node_user_az_subnet_id_prefix}${each.key}"
  pod_subnet_id         = local.aks.network.pod_subnet_id
  vm_size               = local.aks.default.vm_size
  zones                 = [each.key]
  node_count            = var.aks.node_pool.user.node_count
  priority              = var.aks.node_pool.user.priority
  os_disk_size_gb       = local.aks.default.os_disk_size_gb
  os_disk_type          = local.aks.default.os_disk_type
  os_sku                = local.aks.default.os_sku

  lifecycle {
    ignore_changes = [
      eviction_policy,
      node_taints,
    ]
  }
}

resource "azurerm_role_assignment" "aks_metrics" {
  scope                = azurerm_kubernetes_cluster.default.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_kubernetes_cluster.default.oms_agent.0.oms_agent_identity.0.object_id
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "aks-diag"
  target_resource_id         = azurerm_kubernetes_cluster.default.id
  log_analytics_workspace_id = local.log_analytics.workspace_id

  log {
    category = "kube-apiserver"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  log {
    category = "kube-controller-manager"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  log {
    category = "kube-scheduler"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  log {
    category = "kube-audit"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  log {
    category = "kube-audit-admin"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  log {
    category = "guard"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  log {
    category = "cluster-autoscaler"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  log {
    category = "cloud-controller-manager"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  log {
    category = "csi-azuredisk-controller"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  log {
    category = "csi-azurefile-controller"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  log {
    category = "csi-snapshot-controller"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  lifecycle {
    ignore_changes = [
      log_analytics_workspace_id,
    ]
  }
}

# may replace with AAD Pod Identiy in the future (judgement by GA timing and maturity)
resource "azurerm_key_vault_access_policy" "demoapp_kubelet" {
  key_vault_id = local.demoapp.key_vault.id
  tenant_id    = local.tenant_id
  object_id    = azurerm_user_assigned_identity.aks_kubelet.principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}
