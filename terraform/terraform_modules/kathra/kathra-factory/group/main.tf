variable "realm_id" {
}
variable "name" {
}
variable "members" {
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