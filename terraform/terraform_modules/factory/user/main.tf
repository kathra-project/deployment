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
variable "realm_uuid" {
}
variable "jenkins" {
}
variable "gitlab" {
}
variable "keycloak" {
}





resource "keycloak_user" "first_user_wt_password" {
    realm_id    = var.realm_uuid
    username    = var.username
    enabled     = true
    email       = var.email
    first_name  = var.first_name
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
    username      = var.username
    password      = var.password
    release       = var.gitlab.name
    namespace     = var.gitlab.namespace
    kube_config   = var.kube_config
}

module "jenkins_user_init_api_token" {
    source        = "../jenkins/generate_api_token"
    jenkins_host  = var.jenkins.host
    keycloak_host = var.keycloak.host
    username      = var.username
    password      = var.password
    release       = var.jenkins.name
    namespace     = module.jenkins.namespace
    kube_config   = var.kube_config
}

output "user" {
  value = keycloak_user.first_user_wt_password
}
output "jenkins_api_token" {
  value = module.jenkins_user_init_api_token.api_token
}
output "gitlab_api_token" {
  value = module.gitlab_user_init_api_token.api_token
}
