terraform {
  required_version = "~> 1.4.6"
}

module "green" {
  source        = "../../../terraform/green"
  prefix        = var.prefix
  suffix        = var.suffix
  aks           = var.aks
  log_analytics = var.log_analytics
  demoapp       = var.demoapp
  prometheus    = var.prometheus
}
