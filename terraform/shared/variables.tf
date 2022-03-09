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

variable "demoapp_svc_ips" {
  type        = map(string)
  description = "Specify the IPs of the demoapp services manually. This is used like a switch between Blue and Green."
}
