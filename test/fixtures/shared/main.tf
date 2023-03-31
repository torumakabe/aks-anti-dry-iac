terraform {
  required_version = "~> 1.4.4"
}

module "shared" {
  source          = "../../../terraform/shared"
  prefix          = var.prefix
  suffix          = var.suffix
  shared_rg       = var.shared_rg
  demoapp_svc_ips = var.demoapp_svc_ips
}
