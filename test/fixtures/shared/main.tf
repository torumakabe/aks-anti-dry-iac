terraform {
  required_version = "~> 1.0.9"
}

module "shared" {
  source          = "../../../terraform/shared"
  prefix          = var.prefix
  shared_rg       = var.shared_rg
  demoapp_svc_ips = var.demoapp_svc_ips
}
