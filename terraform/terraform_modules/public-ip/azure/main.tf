variable "group" {
    default = "kathra"
}

variable location {
    default = "East US"
}

variable domain_name_label {
    default = null
}

provider "azurerm" {
    version = "~>1.5"
}

resource "azurerm_public_ip" "public_ip" {
  name                = "k8sStaticIp"
  location            = var.location
  resource_group_name = var.group
  allocation_method   = "Static"
  domain_name_label   = var.domain_name_label
}

data "azurerm_public_ip" "public_ip" {
  name                = "k8sStaticIp"
  resource_group_name = var.group
}

output "domain_name_label" {
  value = data.azurerm_public_ip.public_ip.domain_name_label
}

output "public_ip_address" {
  value = data.azurerm_public_ip.public_ip.ip_address
}