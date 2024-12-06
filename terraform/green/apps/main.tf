terraform {
  required_version = "~> 1.10.1"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azurerm_user_assigned_identity" "demoapp" {
  resource_group_name = var.aks.rg.name
  location            = var.aks.rg.location
  name                = "mi-demoapp"
}

resource "azurerm_role_assignment" "demoapp_keyvault" {
  scope                = var.demoapp.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  // role_definition_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6"
  principal_id = azurerm_user_assigned_identity.demoapp.principal_id
}

resource "azurerm_federated_identity_credential" "dempapp" {
  name                = "ficred-demoapp"
  resource_group_name = var.aks.rg.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.demoapp.id
  subject             = "system:serviceaccount:${local.demoapp.service_account.namespace}:${local.demoapp.service_account.name}"
}

resource "azurerm_kubernetes_cluster_extension" "flux" {
  name           = "ext-flux"
  cluster_id     = var.aks.cluster_id
  extension_type = "microsoft.flux"
  configuration_settings = {
    "multiTenancy.enforce"                = "false",
    "image-automation-controller.enabled" = "true",
    "image-reflector-controller.enabled"  = "true",
  }

  provisioner "local-exec" {
    command = <<-EOT
      ${path.module}/scripts/pass-values.sh \
      ${var.aks.rg.name} \
      ${var.aks.cluster_name} \
      ${local.tenant_id} \
      ${azurerm_user_assigned_identity.demoapp.client_id} \
      ${var.demoapp.key_vault.name} \
      ${var.demoapp.ingress_svc.subnet} \
      ${var.demoapp.ingress_svc.ip}
    EOT
  }
}

resource "azurerm_kubernetes_flux_configuration" "base" {
  depends_on = [
    azurerm_kubernetes_cluster_extension.flux,
  ]
  name       = "flux-system"
  cluster_id = var.aks.cluster_id
  namespace  = "flux-system"

  git_repository {
    url              = var.flux.git_repository.url
    reference_type   = var.flux.git_repository.reference_type
    reference_value  = var.flux.git_repository.reference_value
    https_user       = var.flux_git_user
    https_key_base64 = base64encode(var.flux_git_token)
  }

  kustomizations {
    name = "base"
    path = "./flux/clusters/${var.aks.switch}-${var.suffix}"
  }
}
