# If you don't want to manage with files, choose other means such as environment variables.
# https://www.terraform.io/docs/language/values/variables.html

prefix = "yours"
suffix = "prod"

aks = {
  switch = "green"
  rg = {
    location = "japaneast"
  }
  node_pool = {
    system = {
      node_count                   = 3
      only_critical_addons_enabled = true
    }
    user = {
      // one pool per zone
      // total nodes = node_count * 3 AZ
      node_count = 3
      priority   = "Regular"
    }
  }
  aad = {
    admin_group_object_ids = ["your-aad-admin-group-object-id"]
  }
}

log_analytics = {
  workspace = {
    name    = "your-la-workspace-name"
    rg_name = "your-la-workspace-resource-group-name"
  }
}

demoapp = {
  ingress_svc = {
    ip = "10.1.9.4"
  }
  key_vault = {
    name_body = "kv-demoapp"
  }
}

prometheus = {
  enabled                       = true
  data_collection_endpoint_name = "dce-amw-prom"
  data_collection_rule_name     = "dcr-amw-prom"
}
