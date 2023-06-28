variable "prefix" {
  type = string
}

variable "suffix" {
  type = string
}

variable "aks" {
  type = object({
    switch = string
    rg = object({
      location = string
    })
    node_pool = object({
      system = object({
        node_count                   = number
        only_critical_addons_enabled = bool
      })
      user = object({
        node_count = number
        priority   = string
      })
    })
    aad = object({
      admin_group_object_ids = list(string)
    })
  })
}

variable "log_analytics" {
  type = object({
    workspace = object({
      name    = string
      rg_name = string
    })
  })
}


variable "prometheus" {
  type = object({
    enabled                       = bool
    data_collection_endpoint_name = string
    data_collection_rule_name     = string
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
      ip = string # Specify IP address in service LB subnet you want to assign to the demo app's Ingress service
    })
    key_vault = object({
      name_body = string
    })
  })
}
