# If you don't want to manage with files, choose other means such as environment variables.
# https://www.terraform.io/docs/language/values/variables.html

prefix = "yours"
suffix = "int"

shared_rg = {
  location = "japaneast"
}

demoapp_svc_ips = {
  blue  = "10.1.65.4",
  green = "10.1.67.4",
}
