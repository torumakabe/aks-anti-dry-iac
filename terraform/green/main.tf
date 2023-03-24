terraform {
  required_version = "~> 1.4.2"
  # Choose the backend according to your requirements
  # backend "remote" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.49.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.19"
    }
  }
}

provider "azurerm" {
  use_oidc                   = true
  skip_provider_registration = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_kubernetes_cluster" "default" {
  depends_on          = [module.aks] # refresh cluster state before reading
  name                = module.aks.aks_cluster_name
  resource_group_name = module.aks.resource_group_name
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.default.kube_config.0.host
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = [
      "get-token",
      "--login",
      "azurecli",
      "--server-id",
      "6dae42f8-4368-4678-94ff-3960e28e3630"
    ]
  }
}

# Split HCL into two modules (AKS and k8s) due to the following limitation of Terraform
# https://github.com/hashicorp/terraform-provider-kubernetes/issues/1307

module "aks" {
  source        = "./aks"
  prefix        = var.prefix
  suffix        = var.suffix
  aks           = var.aks
  log_analytics = var.log_analytics
  demoapp       = var.demoapp
}

module "kubernetes-config" {
  # workaround for https://github.com/hashicorp/terraform-provider-kubernetes/issues/1867
  depends_on = [module.aks]
  source     = "./kubernetes-config"
  aks = {
    switch = var.aks.switch
    rg = {
      name = local.aks.rg.name
    }
    cluster_name = local.aks.cluster_name
  }
  mi_demoapp = module.aks.mi_demoapp
  demoapp = {
    ingress_svc = {
      subnet = module.aks.svc_lb_subnet_name
      ip     = var.demoapp.ingress_svc.ip
    }
    key_vault = {
      name = local.demoapp.key_vault.name
    }
  }
}
