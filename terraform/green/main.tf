terraform {
  required_version = "~> 1.0.9"
  backend "remote" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.81.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.6"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# Optional: To keep up with the latest version
/*
data "azurerm_kubernetes_service_versions" "current" {
  location        = var.aks_rg.location
  version_prefix  = "1.22"
  include_preview = false
}
*/

resource "azurerm_resource_group" "aks" {
  name     = var.aks_rg.name
  location = var.aks_rg.location
}

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

resource "azurerm_role_assignment" "aks_subnet" {
  scope                = var.aks_network.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_cplane.principal_id

  // Waiting for Azure AD preparation
  provisioner "local-exec" {
    command = "sleep 30"
  }
}

resource "azurerm_role_assignment" "aks_subnet_svc_lb" {
  scope                = var.aks_network.subnet_svc_lb_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_cplane.principal_id

  // Waiting for Azure AD preparation
  provisioner "local-exec" {
    command = "sleep 30"
  }
}


resource "azurerm_kubernetes_cluster" "main" {
  depends_on = [
    azurerm_role_assignment.aks_mi_operator,
    azurerm_role_assignment.aks_subnet,
    azurerm_role_assignment.aks_subnet_svc_lb,
  ]
  name = local.aks_cluster_name
  # Optional: To keep up with the latest version
  # kubernetes_version  = data.azurerm_kubernetes_service_versions.current.latest_version
  kubernetes_version  = "1.22.2"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  node_resource_group = "${azurerm_resource_group.aks.name}-node"
  dns_prefix          = local.aks_cluster_name
  sku_tier            = "Free"

  default_node_pool {
    name = "default"
    type = "VirtualMachineScaleSets"
    # Optional: To keep up with the latest version
    # orchestrator_version  = data.azurerm_kubernetes_service_versions.current.latest_version
    orchestrator_version         = "1.22.2"
    vnet_subnet_id               = var.aks_network.subnet_id
    pod_subnet_id                = var.aks_network.pod_subnet_id
    availability_zones           = [1, 2, 3]
    node_count                   = 3
    vm_size                      = "Standard_D2ds_v4"
    only_critical_addons_enabled = false

    os_disk_size_gb = 30
    os_disk_type    = "Ephemeral"
    os_sku          = "Ubuntu"
    # os_sku = "CBLMariner"
  }

  identity {
    type                      = "UserAssigned"
    user_assigned_identity_id = azurerm_user_assigned_identity.aks_cplane.id
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.aks_kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.aks_kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.aks_kubelet.id
  }

  role_based_access_control {
    enabled = true
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
    network_mode   = "transparent"
    service_cidr   = "10.1.16.0/20"
    dns_service_ip = "10.1.16.10"
    // Unnecessary it now practically, but for passing validation of terraform
    docker_bridge_cidr = "172.17.0.1/16"

    load_balancer_sku = "standard"
    load_balancer_profile {
      managed_outbound_ip_count = 1
    }
  }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = var.log_analytics.workspace_id
    }
    azure_policy {
      enabled = true
    }
    kube_dashboard {
      enabled = false
    }
  }

  lifecycle {
    ignore_changes = [
      addon_profile,
      default_node_pool[0].node_labels,
    ]
  }
}

resource "azurerm_role_assignment" "aks_metrics" {
  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_kubernetes_cluster.main.addon_profile.0.oms_agent.0.oms_agent_identity.0.object_id
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "aks-diag"
  target_resource_id         = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id = var.log_analytics.workspace_id

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

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
}

resource "kubernetes_cluster_role" "log_reader" {
  metadata {
    name = "containerhealth-log-reader"
  }

  rule {
    api_groups = ["", "metrics.k8s.io", "extensions", "apps"]
    resources  = ["pods/log", "events", "nodes", "pods", "deployments", "replicasets"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "log_reader" {
  metadata {
    name = "containerhealth-read-logs-global"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "containerhealth-log-reader"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "User"
    name      = "clusterUser"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_config_map" "oms_agent" {
  depends_on = [azurerm_role_assignment.aks_metrics]
  metadata {
    name      = "container-azm-ms-agentconfig"
    namespace = "kube-system"
  }

  data = {
    schema-version                           = "v1"
    config-version                           = "ver1"
    log-data-collection-settings             = <<EOT
[log_collection_settings]
   [log_collection_settings.stdout]
      enabled = true
      exclude_namespaces = ["kube-system"]
   [log_collection_settings.stderr]
      enabled = true
      exclude_namespaces = ["kube-system"]
   [log_collection_settings.env_var]
      enabled = true
   [log_collection_settings.enrich_container_logs]
      enabled = false
   [log_collection_settings.collect_all_kube_events]
      enabled = false
EOT
    alertable-metrics-configuration-settings = <<EOT
[alertable_metrics_configuration_settings.container_resource_utilization_thresholds]
    container_memory_working_set_threshold_percentage = 80.0
[alertable_metrics_configuration_settings.pv_utilization_thresholds]
    pv_usage_threshold_percentage = 80.0
EOT
    prometheus-data-collection-settings      = <<EOT
[prometheus_data_collection_settings.node]
    interval = "1m"
    urls = ["http://$NODE_IP:9103/metrics"]
EOT
    metric_collection_settings               = <<EOT
[metric_collection_settings.collect_kube_system_pv_metrics]
    enabled = true
EOT
  }
}

# may replace with AAD Pod Identiy in the future (judgement by GA timing and maturity)
resource "azurerm_key_vault_access_policy" "demoapp_kubelet" {
  key_vault_id = var.demoapp.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.aks_kubelet.principal_id

  secret_permissions = [
    "get",
    "list",
  ]
}

resource "kubernetes_config_map" "shared" {
  metadata {
    name      = "shared"
    namespace = "default"
  }

  data = {
    tenant_id     = data.azurerm_client_config.current.tenant_id
    mi_kubelet_id = azurerm_user_assigned_identity.aks_kubelet.principal_id
  }
}

# workaround. will be removed when kustomize-controller make substituteFrom reference-able across namespace
# https://github.com/fluxcd/kustomize-controller/issues/368
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "flux uninstall -s"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels,
    ]
  }
}

resource "kubernetes_config_map" "ids" {
  depends_on = [
    kubernetes_namespace.flux_system
  ]
  metadata {
    name      = "ids"
    namespace = "flux-system"
  }

  data = {
    tenant_id     = data.azurerm_client_config.current.tenant_id
    mi_kubelet_id = azurerm_user_assigned_identity.aks_kubelet.client_id
  }
}
