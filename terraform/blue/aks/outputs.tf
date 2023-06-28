output "resource_group_name" {
  value = azurerm_resource_group.aks.name
}

output "resource_group_location" {
  value = azurerm_resource_group.aks.location
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.default.name
}

output "aks_cluster_id" {
  value = azurerm_kubernetes_cluster.default.id
}

output "aks_oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.default.oidc_issuer_url
}

output "svc_lb_subnet_name" {
  value = split("/", local.aks.network.svc_lb_subnet_id)[length(split("/", local.aks.network.svc_lb_subnet_id)) - 1]
}
