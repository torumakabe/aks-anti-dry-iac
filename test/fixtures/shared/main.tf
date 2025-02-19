terraform {
  required_version = "~> 1.10.5"
}

module "shared" {
  source             = "../../../terraform/shared"
  prefix             = var.prefix
  suffix             = var.suffix
  shared_rg          = var.shared_rg
  demoapp            = var.demoapp
  prometheus_grafana = var.prometheus_grafana
}
