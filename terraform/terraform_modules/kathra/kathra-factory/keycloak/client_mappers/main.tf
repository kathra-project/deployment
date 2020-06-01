
variable "realm_id" {
  
}
variable "client_id" {
  
}



resource "keycloak_openid_user_attribute_protocol_mapper" "username" {
    realm_id       = var.realm_id
    client_id      = var.client_id
    name           = "username"
    user_attribute = "username"
    claim_name     = "preferred_username"
}
resource "keycloak_openid_user_attribute_protocol_mapper" "given_name" {
    realm_id        = var.realm_id
    client_id       = var.client_id
    name            = "family_name"
    user_attribute  = "firstName"
    claim_name      = "given_name"
}
resource "keycloak_openid_user_attribute_protocol_mapper" "family_name" {
    realm_id        = var.realm_id
    client_id       = var.client_id
    name            = "lastName"
    user_attribute  = "lastName"
    claim_name      = "family_name"
}
resource "keycloak_openid_user_attribute_protocol_mapper" "email" {
    realm_id        = var.realm_id
    client_id       = var.client_id
    name            = "email"
    user_attribute  = "email"
    claim_name      = "email"
}

resource "keycloak_openid_user_property_protocol_mapper" "client_ip_address" {
    realm_id       = var.realm_id
    client_id      = var.client_id
    name           = "client-ip-address-mapper"
    user_property  = "clientAddress"
    claim_name     = "clientAddress"
}

resource "keycloak_openid_group_membership_protocol_mapper" "group_membership_mapper" {
    realm_id       = var.realm_id
    client_id      = var.client_id
    name           = "group-membership-mapper"
    claim_name     = "groups"
}
resource "keycloak_openid_user_realm_role_protocol_mapper" "user_realm_role_mapper" {
    realm_id        = var.realm_id
    client_id       = var.client_id
    name            = "user-realm-role-mapper"
    claim_name      = "role list"
}
