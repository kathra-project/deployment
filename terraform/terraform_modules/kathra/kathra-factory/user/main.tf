variable "firstname" {
}
variable "lastname" {
}
variable "email" {
}
variable "username" {
}
variable "password" {
}
variable "realm_id" {
}
variable "jenkins" {
}
variable "gitlab" {
}
variable "keycloak" {
}
variable "namespace" {
}
variable "kube_config" {
}


provider "keycloak" {
    client_id     = var.keycloak.client_id
    username      = var.keycloak.username
    password      = var.keycloak.password
    url           = var.keycloak.url
    version       = "1.17.1"
    initial_login = false
}


resource "keycloak_user" "user" {
    realm_id    = var.realm_id
    username    = var.username
    enabled     = true
    email       = var.email
    first_name  = var.firstname
    last_name   = var.lastname
    initial_password {
      value     = var.password
      temporary = false
    }
}

module "gitlab_user_init_api_token" {
    source        = "../gitlab/generate_api_token"
    gitlab_host   = var.gitlab.host
    keycloak_host = var.keycloak.host
    username      = keycloak_user.user.username
    password      = var.password
    release       = var.gitlab.name
    namespace     = var.gitlab.namespace
    kube_config   = var.kube_config
}

module "jenkins_user_init_api_token" {
    source        = "../jenkins/generate_api_token"
    jenkins_host  = var.jenkins.host
    keycloak_host = var.keycloak.host
    username      = keycloak_user.user.username
    password      = var.password
    release       = var.jenkins.name
    namespace     = var.namespace
    kube_config   = var.kube_config
}

output "username" {
  value = keycloak_user.user.username
}
output "password" {
  value = keycloak_user.user.initial_password[0].value
}
output "jenkins_api_token" {
  value = module.jenkins_user_init_api_token.api_token
}
output "gitlab_api_token" {
  value = module.gitlab_user_init_api_token.api_token
}
