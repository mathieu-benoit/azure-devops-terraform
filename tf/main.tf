provider "azurerm" {
  version = "=2.4.0"
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}
