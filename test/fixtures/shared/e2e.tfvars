# If you don't want to manage with files, choose other means such as environment variables.
# https://www.terraform.io/docs/language/values/variables.html

prefix = "yours"
suffix = "e2e"

shared_rg = {
  location = "japaneast"
}

demoapp_svc_ips = {
  blue  = "10.1.68.4",
  green = "10.1.73.4",
}
