variable "suffix" {
  type = string
}

variable "aks" {
  type = object({
    switch = string
    rg = object({
      name     = string
      location = string
    })
    cluster_name    = string
    cluster_id      = string
    oidc_issuer_url = string
  })
}

variable "flux" {
  type = object({
    git_repository = object({
      url             = string
      reference_type  = string
      reference_value = string
    })
  })
}

# Sepaarate variable from flux variable object, as it's sensitive
variable "flux_git_user" {
  type      = string
  sensitive = true
}

# Sepaarate variable for flux variable object, as it's sensitive
variable "flux_git_token" {
  type      = string
  sensitive = true
}

variable "demoapp" {
  type = object({
    ingress_svc = object({
      subnet = string
      ip     = string
    })
    key_vault = object({
      name = string
      id   = string
    })
  })
}
