terraform {
  required_version = "~> 1.3.0"
}

module "green" {
  source        = "../../../terraform/green"
  prefix        = var.prefix
  suffix        = var.suffix
  aks           = var.aks
  log_analytics = var.log_analytics
  demoapp       = var.demoapp
}
