terraform {
  required_version = "~> 1.9.6"
  # Choose the backend according to your requirements
  # backend "remote" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.3.0"
    }
  }
}

provider "azurerm" {
  use_oidc                        = true
  resource_provider_registrations = "none"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

module "aks" {
  source        = "./aks"
  prefix        = var.prefix
  suffix        = var.suffix
  aks           = var.aks
  log_analytics = var.log_analytics
  prometheus    = var.prometheus
}

module "apps" {
  depends_on = [module.aks]
  source     = "./apps"
  suffix     = var.suffix
  aks = {
    switch = var.aks.switch
    rg = {
      name     = module.aks.resource_group_name
      location = module.aks.resource_group_location
    }
    cluster_name    = module.aks.aks_cluster_name
    cluster_id      = module.aks.aks_cluster_id
    oidc_issuer_url = module.aks.aks_oidc_issuer_url
  }
  demoapp = {
    ingress_svc = {
      subnet = module.aks.svc_lb_subnet_name
      ip     = var.demoapp.ingress_svc.ip
    }
    key_vault = {
      name = local.demoapp.key_vault.name
      id   = local.demoapp.key_vault.id
    }
  }
  flux = {
    git_repository = {
      url             = var.flux.git_repository.url
      reference_type  = var.flux.git_repository.reference_type
      reference_value = var.flux.git_repository.reference_value
    }
  }
  flux_git_user  = var.flux_git_user
  flux_git_token = var.flux_git_token
}
