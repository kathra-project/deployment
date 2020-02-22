
variable "resource_group_name" {
    default = "kathra"
}

variable "ip" {

}
variable "domain_name" {

}

resource "azurerm_dns_zone" "dns" {
    name                = var.domain_name
    resource_group_name = var.resource_group_name
}

resource "azurerm_dns_a_record" "kathraWildCard" {
    name                = "*.kathra"
    zone_name           = var.domain_name
    resource_group_name = var.resource_group_name
    ttl                 = 300
    records             = [var.ip]
}