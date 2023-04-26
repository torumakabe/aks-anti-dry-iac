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
}
