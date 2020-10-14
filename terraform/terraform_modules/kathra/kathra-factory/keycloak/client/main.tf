variable "realm" {
}
variable "client_id" {
}
variable "redirect_uri" {
}
variable "web_origins" {
    default = [ "*" ]
}
variable "keycloak_url" {
}

resource "keycloak_openid_client" "client" {
    realm_id                      = var.realm
    client_id                     = var.client_id

    name                          = var.client_id
    enabled                       = true
    standard_flow_enabled         = true 
    implicit_flow_enabled         = true 
    direct_access_grants_enabled  = true
    service_accounts_enabled      = true   

    access_type                   = "CONFIDENTIAL"
    valid_redirect_uris           = [
        var.redirect_uri
    ]
    web_origins                   = var.web_origins
}

module "mappers" {
    source      = "./../client_mappers"
    realm_id    = var.realm
    client_id   = keycloak_openid_client.client.id
}

output "host" {
  value = replace(var.keycloak_url, "https://", "")
}
output "well_known_url" {
  value = "${var.keycloak_url}/auth/realms/${var.realm}/.well-known/openid-configuration"
}
output "token_url" {
  value = "${var.keycloak_url}/auth/realms/${var.realm}/protocol/openid-connect/token"
}
output "auth_url" {
  value =  "${var.keycloak_url}/auth/realms/${var.realm}/protocol/openid-connect/auth"
}
output "client_id" {
  value = keycloak_openid_client.client.client_id
}
output "client_secret" {
  value = keycloak_openid_client.client.client_secret
}


