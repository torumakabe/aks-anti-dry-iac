# If you don't want to manage with files, choose other means such as environment variables.
# https://www.terraform.io/docs/language/values/variables.html

prefix = "yours"
suffix = "dev"

shared_rg = {
  location = "japaneast"
}

demoapp = {
  domain = "internal.example"
  target = [
    "blue",
    "green"
  ]
}

prometheus_grafana = {
  enabled                       = false
  workspace_name                = "amw-prom"
  data_collection_endpoint_name = "dce-amw-prom"
  data_collection_rule_name     = "dcr-amw-prom"
}
