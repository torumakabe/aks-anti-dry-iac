variable "prefix" {
  type = string
}

variable "suffix" {
  type = string
}

variable "shared_rg" {
  type = object({
    location = string
  })
}

variable "demoapp" {
  type = object({
    domain = string
    target = list(string)
  })
}

variable "prometheus_grafana" {
  type = object({
    enabled                       = bool
    workspace_name                = string
    data_collection_endpoint_name = string
    data_collection_rule_name     = string
  })
}
