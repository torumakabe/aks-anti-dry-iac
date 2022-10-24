output "resource_group_name" {
  value = azurerm_resource_group.aks.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.default.name
}

output "mi_demoapp" {
  value = azurerm_user_assigned_identity.demoapp.client_id
}

output "svc_lb_subnet_name" {
  value = split("/", local.aks.network.svc_lb_subnet_id)[length(split("/", local.aks.network.svc_lb_subnet_id)) - 1]
}
