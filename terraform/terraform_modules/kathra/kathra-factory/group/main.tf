variable "keycloak" {
}
variable "realm_id" {
}
variable "name" {
}
variable "members" {
}

provider "keycloak" {
    client_id     = var.keycloak.client_id
    username      = var.keycloak.username
    password      = var.keycloak.password
    url           = var.keycloak.url
    version       = "1.17.1"
    initial_login = false
}

resource "keycloak_group" "root_group" {
    realm_id = var.realm_id
    name     = var.name
}

resource "keycloak_group_memberships" "members" {
    realm_id = var.realm_id
    group_id = keycloak_group.root_group.id
    members  = var.members
}