variable "keycloak_realm" {
}
variable "first_user_login" {
  default = null
}
variable "first_user_password" {
  default = null
}
variable "first_group_name" {
  default = null
}
variable "keycloak_url" {
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
    count       = var.first_group_name == null ? 0 : 1

    realm_id  = keycloak_realm.realm.id
    parent_id = keycloak_group.root_group.id
    name      = var.first_group_name
}

resource "keycloak_user" "first_user_wt_password" {
    count       = var.first_user_login == null ? 0 : 1
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
    count       = var.first_group_name == null || var.first_user_login == null ? 0 : 1

    realm_id = keycloak_realm.realm.id
    group_id = keycloak_group.first_group[0].id

    members  = [keycloak_user.first_user_wt_password[0].username]
}

output "name" {
    value = keycloak_realm.realm.realm
}

output "id" {
    value = keycloak_realm.realm.id
}

output "root_group" {
  value = keycloak_group.root_group
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
