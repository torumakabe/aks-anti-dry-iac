output "resource_group_name" {
  value = azurerm_resource_group.aks.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.default.name
}

output "mi_kubelet_id" {
  value = azurerm_user_assigned_identity.aks_kubelet.client_id
}

output "svc_lb_subnet_name" {
  value = split("/", local.aks.network.svc_lb_subnet_id)[length(split("/", local.aks.network.svc_lb_subnet_id)) - 1]
}
