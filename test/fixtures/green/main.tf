terraform {
  required_version = "~> 1.0.9"
}

module "green" {
  source        = "../../../terraform/green"
  prefix        = var.prefix
  aks_rg        = var.aks_rg
  aks_network   = var.aks_network
  log_analytics = var.log_analytics
  demoapp       = var.demoapp
}
