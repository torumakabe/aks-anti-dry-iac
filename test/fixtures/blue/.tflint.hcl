plugin "azurerm" {
    enabled = true
    version = "0.13.1"
    source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

rule "terraform_unused_declarations" {
  enabled = true
}
