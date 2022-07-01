terraform {
  required_version = "~> 1.2.4"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.12"
    }
  }
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
  metadata {
    name      = "container-azm-ms-agentconfig"
    namespace = "kube-system"
  }

  data = {
    schema-version                           = "v1"
    config-version                           = "v1"
    log-data-collection-settings             = <<EOT
[log_collection_settings]
  [log_collection_settings.stdout]
    enabled = true
    exclude_namespaces = ["kube-system", "calico-system", "tigera-operator"]
  [log_collection_settings.stderr]
    enabled = true
    exclude_namespaces = ["kube-system", "calico-system", "tigera-operator"]
  [log_collection_settings.env_var]
    enabled = true
  [log_collection_settings.enrich_container_logs]
    enabled = false
  [log_collection_settings.collect_all_kube_events]
    enabled = false
  [log_collection_settings.schema]
    containerlog_schema_version = "v2"
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
  urls = ["http://$NODE_IP:19100/metrics"]
EOT
    metric_collection_settings               = <<EOT
[metric_collection_settings.collect_kube_system_pv_metrics]
  enabled = true
EOT
  }
}

# workaround. will be removed when kustomize-controller make substituteFrom reference-able across namespace
# https://github.com/fluxcd/kustomize-controller/issues/368
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
    labels = {
      aks-rg-name      = var.aks.rg.name
      aks-cluster-name = var.aks.cluster_name
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/../../../flux/scripts/destruct.sh ${self.metadata[0].labels.aks-rg-name} ${self.metadata[0].labels.aks-cluster-name} || true"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels,
    ]
  }
}

resource "kubernetes_config_map" "flux_configs" {
  depends_on = [
    kubernetes_namespace.flux_system
  ]
  metadata {
    name      = "flux-configs"
    namespace = "flux-system"
  }

  data = {
    tenant_id                  = local.tenant_id
    mi_kubelet_id              = var.mi_kubelet_id
    demoapp_key_vault_name     = var.demoapp.key_vault.name
    demoapp_ingress_svc_subnet = var.demoapp.ingress_svc.subnet
    demoapp_ingress_svc_ip     = var.demoapp.ingress_svc.ip
  }
}
