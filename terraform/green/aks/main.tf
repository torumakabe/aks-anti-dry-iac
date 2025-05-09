terraform {
  required_version = "~> 1.11.3"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
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
  version_prefix  = "1.32"
  include_preview = false
}
*/

resource "azurerm_user_assigned_identity" "aks_cplane" {
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  name                = "mi-aks-cplane"
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

resource "azurerm_public_ip_prefix" "nat_outbound_aks_user_az" {
  for_each            = toset(["1", "2", "3"])
  name                = "ippre-nat-outbound-aks-az${each.key}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  prefix_length       = 30
  zones               = [each.key]
}

resource "azurerm_nat_gateway" "aks_user_az" {
  for_each            = toset(["1", "2", "3"])
  name                = "ng-aks-user-az${each.key}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_prefix_association" "aks_user_az" {
  for_each            = toset(["1", "2", "3"])
  nat_gateway_id      = azurerm_nat_gateway.aks_user_az[each.key].id
  public_ip_prefix_id = azurerm_public_ip_prefix.nat_outbound_aks_user_az[each.key].id
}

resource "azurerm_subnet_nat_gateway_association" "aks_user_az" {
  for_each       = toset(["1", "2", "3"])
  subnet_id      = "${local.aks.network.node_user_az_subnet_id_prefix}${each.key}"
  nat_gateway_id = azurerm_nat_gateway.aks_user_az[each.key].id

  // Waiting to avoid subnet conflict
  provisioner "local-exec" {
    command = "sleep 10"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "sleep 10"
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
  kubernetes_version        = local.aks.default.orchestrator_version
  location                  = azurerm_resource_group.aks.location
  resource_group_name       = azurerm_resource_group.aks.name
  node_resource_group       = "${azurerm_resource_group.aks.name}-node"
  dns_prefix                = local.aks.cluster_name
  sku_tier                  = "Standard"
  local_account_disabled    = true
  workload_identity_enabled = true
  oidc_issuer_enabled       = true
  maintenance_window {
    allowed {
      day   = "Wednesday"
      hours = [1]
    }
  }
  node_os_upgrade_channel = "NodeImage"
  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Thursday"
    start_time  = "01:00"
    utc_offset  = "+09:00"
  }
  // add as needed
  api_server_access_profile {
    authorized_ip_ranges = [
      "${chomp(data.http.my_public_ip.response_body)}/32",
      azurerm_public_ip_prefix.nat_outbound_aks_user_az["1"].ip_prefix,
      azurerm_public_ip_prefix.nat_outbound_aks_user_az["2"].ip_prefix,
      azurerm_public_ip_prefix.nat_outbound_aks_user_az["3"].ip_prefix
    ]
  }

  default_node_pool {
    name = "system"
    type = "VirtualMachineScaleSets"
    # Optional: To keep up with the latest version
    # orchestrator_version  = data.azurerm_kubernetes_service_versions.current.latest_version
    orchestrator_version         = local.aks.default.orchestrator_version
    vnet_subnet_id               = local.aks.network.node_system_subnet_id
    zones                        = [1, 2, 3]
    node_count                   = var.aks.node_pool.system.node_count
    vm_size                      = local.aks.default.vm_size
    only_critical_addons_enabled = var.aks.node_pool.system.only_critical_addons_enabled

    os_disk_size_gb = local.aks.default.os_disk_size_gb
    os_disk_type    = local.aks.default.os_disk_type
    os_sku          = local.aks.default.os_sku
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_cplane.id]
  }

  role_based_access_control_enabled = true
  azure_active_directory_role_based_access_control {
    admin_group_object_ids = var.aks.aad.admin_group_object_ids
    azure_rbac_enabled     = true
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
    network_data_plane  = "cilium"
    network_policy      = "cilium"

    load_balancer_sku = "standard"
    load_balancer_profile {
      managed_outbound_ip_count = 1
    }
  }

  azure_policy_enabled = true
  oms_agent {
    log_analytics_workspace_id      = local.log_analytics.workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  dynamic "monitor_metrics" {
    for_each = var.prometheus.enabled ? toset(["1"]) : toset([])
    content {}
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 24
  cost_analysis_enabled        = true

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_labels,
      microsoft_defender,
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each              = toset(["1", "2", "3"])
  name                  = "az${each.key}"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.default.id
  orchestrator_version  = local.aks.default.orchestrator_version
  vnet_subnet_id        = "${local.aks.network.node_user_az_subnet_id_prefix}${each.key}"
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

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "aks-diag"
  target_resource_id         = azurerm_kubernetes_cluster.default.id
  log_analytics_workspace_id = local.log_analytics.workspace_id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "guard"
  }

  enabled_log {
    category = "cluster-autoscaler"
  }

  metric {
    category = "AllMetrics"
    enabled  = false
  }

  lifecycle {
    ignore_changes = [
      log_analytics_workspace_id,
    ]
  }
}

resource "azurerm_monitor_data_collection_rule" "dcr_azmon_container_insights" {
  name                = "dcr-azmon-container-insights-${local.aks.cluster_name}"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location

  destinations {
    log_analytics {
      workspace_resource_id = local.log_analytics.workspace_id
      name                  = "ciworkspace"
    }
  }

  data_flow {
    streams      = ["Microsoft-ContainerInsights-Group-Default", "Microsoft-Syslog"]
    destinations = ["ciworkspace"]
  }

  data_sources {
    syslog {
      streams        = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "cron", "daemon", "mark", "kern", "local0", "local1", "local2", "local3", "local4", "local5", "local6", "local7", "lpr", "mail", "news", "syslog", "user", "uucp"]
      log_levels     = ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
      name           = "sysLogsDataSource"
    }

    extension {
      streams        = ["Microsoft-ContainerInsights-Group-Default"]
      extension_name = "ContainerInsights"
      name           = "ContainerInsightsExtension"
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "dcra_azmon_container_insights" {
  name                    = "dcra-azmon-container-insights-${local.aks.cluster_name}"
  target_resource_id      = azurerm_kubernetes_cluster.default.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr_azmon_container_insights.id
}

resource "azurerm_monitor_data_collection_rule_association" "dce_amw_prometheus" {
  for_each = var.prometheus.enabled ? toset(["1"]) : toset([])

  target_resource_id          = azurerm_kubernetes_cluster.default.id
  data_collection_endpoint_id = local.prometheus.data_collection_endpoint_id
}

resource "azurerm_monitor_data_collection_rule_association" "dcra_amw_prometheus" {
  for_each = var.prometheus.enabled ? toset(["1"]) : toset([])

  name                    = "dcra-amw-prom-${local.aks.cluster_name}"
  target_resource_id      = azurerm_kubernetes_cluster.default.id
  data_collection_rule_id = local.prometheus.data_collection_rule_id
}

