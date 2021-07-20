# If you don't want to manage with files, choose other means such as environment variables.
# https://www.terraform.io/docs/language/values/variables.html

prefix = "your-prefix"
shared_rg = {
  name     = "rg-aks-anti-dry-shared"
  location = "japaneast"
}
demoapp_svc_ips = {
  # blue  = "10.0.32.4",
  # green = "10.0.80.4",
}
ci_sp_oid = "your-service-principal-object-id-for-ci"
