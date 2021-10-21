# If you don't want to manage with files, choose other means such as environment variables.
# https://www.terraform.io/docs/language/values/variables.html

prefix = "your-prefix"
shared_rg = {
  name     = "rg-aks-anti-dry-shared-ci"
  location = "japaneast"
}
demoapp_svc_ips = {
  blue  = "10.1.33.4",
  green = "10.1.35.4",
}
