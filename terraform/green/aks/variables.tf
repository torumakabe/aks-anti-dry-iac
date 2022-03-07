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
        node_count = number
      })
      user = object({
        node_count = number
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
    key_vault = object({
      name_body = string
    })
  })
}
