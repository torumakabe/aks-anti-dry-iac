# If you don't want to manage with files, choose other means such as environment variables.
# https://www.terraform.io/docs/language/values/variables.html

prefix = "yours"
suffix = "e2e"

shared_rg = {
  location = "japaneast"
}

demoapp = {
  domain = "internal.test"
  target = [
    "blue",
    "green"
  ]
}
