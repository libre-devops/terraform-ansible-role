terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = ">= 1.5.0, < 2.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.0, < 3.0.0"
    }
  }

  # State holds the role variables, sensitive ones included, so keep it in a protected backend.
  backend "azurerm" {}
}
