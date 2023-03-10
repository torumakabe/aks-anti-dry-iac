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
