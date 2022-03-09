output "demoapp_public_endpoint_ip" {
  value = azurerm_public_ip.demoapp.ip_address
}

output "demoapp_backend_service_subnet_blue" {
  value = azurerm_subnet.aks_blue_svc_lb.address_prefixes
}

output "demoapp_backend_service_subnet_green" {
  value = azurerm_subnet.aks_green_svc_lb.address_prefixes
}
