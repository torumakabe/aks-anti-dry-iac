terraform {
  required_version = "~> 1.3.7"
}

module "blue" {
  source        = "../../../terraform/blue"
  prefix        = var.prefix
  suffix        = var.suffix
  aks           = var.aks
  log_analytics = var.log_analytics
  demoapp       = var.demoapp
}
