variable "aks" {
  type = object({
    switch = string
    rg = object({
      name = string
    })
    cluster_name = string
  })
}

variable "mi_kubelet_id" {
  type = string
}

variable "demoapp" {
  type = object({
    ingress_svc = object({
      subnet = string
      ip     = string
    })
    key_vault = object({
      name = string
    })
  })
}
