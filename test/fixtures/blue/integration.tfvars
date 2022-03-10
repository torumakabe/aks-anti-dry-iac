# If you don't want to manage with files, choose other means such as environment variables.
# https://www.terraform.io/docs/language/values/variables.html

prefix = "yours"
suffix = "integ"

aks = {
  switch = "blue"
  rg = {
    location = "japaneast"
  }
  node_pool = {
    system = {
      // one pool per zone
      // total nodes = node_count * 3 AZ
      node_count = 2
    }
    user = {
      node_count = 1
    }
  }
  aad = {
    // dummy UUID
    admin_group_object_ids = ["91e30d0f-b3d7-40d6-b900-d21003632dab"]
  }
}

log_analytics = {
  workspace = {
    name    = "dummy"
    rg_name = "dummy"
  }
}

demoapp = {
  ingress_svc = {
    ip = "10.1.65.4"
  }
  key_vault = {
    name_body = "kv-demoapp"
  }
}