variable "gitlab_host" {
}
variable "keycloak_host" {
}
variable "username" {
}
variable "password" {
}
variable "namespace" {
}
variable "release" { 
}
variable "kube_config" {
}


data "external" "api_token" {
    program = ["bash", "-c", "${path.module}/generate_api_token.sh"]
    query = {
       gitlab_host   = var.gitlab_host
       keycloak_host = var.keycloak_host 
       username      = var.username
       password      = var.password
       kube_config   = jsonencode(var.kube_config)
       namespace     = var.namespace
       release_name  = "gitlab"
       secret_name   = "factory-token-store"
       secret_key    = "gitlab-${var.username}"
    }
}

output "api_token" {
  value = data.external.api_token.result.token
}