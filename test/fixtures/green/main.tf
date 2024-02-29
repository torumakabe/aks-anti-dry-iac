terraform {
  required_version = "~> 1.7.4"
}

module "green" {
  source         = "../../../terraform/green"
  prefix         = var.prefix
  suffix         = var.suffix
  aks            = var.aks
  log_analytics  = var.log_analytics
  prometheus     = var.prometheus
  flux           = var.flux
  flux_git_user  = var.flux_git_user
  flux_git_token = var.flux_git_token
  demoapp        = var.demoapp
}
