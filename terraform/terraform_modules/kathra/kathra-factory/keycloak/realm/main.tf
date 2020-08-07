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
variable "first_user_login" {
}
variable "first_user_password" {
}
variable "first_group_name" {
}




provider "keycloak" {
    client_id     = var.keycloak_client_id
    username      = var.keycloak_username
    password      = var.keycloak_password
    url           = var.keycloak_url
    version       = "1.19.0"
    initial_login = false
}

resource "keycloak_realm" "realm" {
    realm                   = var.keycloak_realm
    enabled                 = true
    display_name            = var.keycloak_realm
    display_name_html       = "<b>${var.keycloak_realm}</b>"

    access_token_lifespan                       = "24h0m0s"
    access_token_lifespan_for_implicit_flow     = "24h0m0s"
}

resource "keycloak_group" "root_group" {
    realm_id = keycloak_realm.realm.id
    name     = "kathra-projects"
}

resource "keycloak_group" "first_group" {
    realm_id  = keycloak_realm.realm.id
    parent_id = keycloak_group.root_group.id
    name      = var.first_group_name
}

resource "keycloak_user" "first_user_wt_password" {
    realm_id    = keycloak_realm.realm.id
    username    = var.first_user_login
    enabled     = true

    email       = "${var.first_user_login}@kathra.org"
    first_name  = "user"
    last_name   = ""
    initial_password {
      value     = var.first_user_password
      temporary = false
    }
}

resource "keycloak_group_memberships" "group_members" {
    realm_id = keycloak_realm.realm.id
    group_id = keycloak_group.first_group.id

    members  = [
        keycloak_user.first_user_wt_password.username
    ]
}

output "name" {
    value = keycloak_realm.realm.realm
}

output "id" {
    value = keycloak_realm.realm.id
}

output "first_user" {
    value = {
        username = var.first_user_login
        password = var.first_user_password
    }
}


output "token_url" {
  value = "${var.keycloak_url}/auth/realms/${keycloak_realm.realm.realm}/protocol/openid-connect/token"
}
output "auth_url" {
  value = "${var.keycloak_url}/auth/realms/${keycloak_realm.realm.realm}/protocol/openid-connect/auth"
}
output "well_known_url" {
  value = "${var.keycloak_url}/auth/realms/${keycloak_realm.realm.realm}/.well-known/openid-configuration"
}
output "logout_url" {
  value = "${var.keycloak_url}/auth/realms/${keycloak_realm.realm.realm}/protocol/openid-connect/logout?redirect_uri=encodedRedirectUri"
}
output "url" {
  value = "${var.keycloak_url}/auth/realms/${keycloak_realm.realm.realm}"
}
