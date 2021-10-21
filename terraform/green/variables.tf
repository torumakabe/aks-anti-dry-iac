variable "prefix" {
  type = string
}

variable "aks_rg" {
  type = object({
    name     = string
    location = string
  })
}

variable "aks_network" {
  type = object({
    pod_subnet_id    = string
    subnet_id        = string
    subnet_svc_lb_id = string
  })
}

variable "log_analytics" {
  type = object({
    workspace_id = string
  })
  sensitive = true
}

variable "demoapp" {
  type = object({
    key_vault_id = string
  })
  sensitive = true
}
