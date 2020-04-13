variable "keycloak_realm" {
}
variable "keycloak_url" {
}
variable "keycloak_client_id" {
}
variable "keycloak_username" {
}
variable "keycloak_password" {
}



provider "keycloak" {
    client_id     = var.keycloak_client_id
    username      = var.keycloak_username
    password      = var.keycloak_password
    url           = var.keycloak_url
    version       = "1.17.1"
    initial_login = false
}

resource "keycloak_realm" "realm" {
    realm                   = var.keycloak_realm
    enabled                 = true
    display_name            = var.keycloak_realm
    display_name_html       = "<b>${var.keycloak_realm}</b>"
}

output "name" {
    value = keycloak_realm.realm.realm
}
