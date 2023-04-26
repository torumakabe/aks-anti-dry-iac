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

variable "demoapp" {
  type = object({
    domain = string
    target = list(string)
  })

  validation {
    condition     = can([for target in var.demoapp.target : regex("^(blue|green)$", target)])
    error_message = "demoapp.target must be only 'blue', 'green' or empty"
  }
}
