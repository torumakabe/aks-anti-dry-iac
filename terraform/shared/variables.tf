variable "prefix" {
  type = string
}

variable "shared_rg" {
  type = object({
    name     = string
    location = string
  })
}

variable "demoapp_svc_ips" {
  type = map(string)
}

variable "ci_sp_oid" {
  type = string
}
