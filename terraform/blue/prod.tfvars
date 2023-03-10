# If you don't want to manage with files, choose other means such as environment variables.
# https://www.terraform.io/docs/language/values/variables.html

prefix = "yours"
suffix = "prod"

aks = {
  switch = "blue"
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
    ip = "10.1.68.4"
  }
  key_vault = {
    name_body = "kv-demoapp"
  }
}
