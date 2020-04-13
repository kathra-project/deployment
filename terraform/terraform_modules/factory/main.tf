variable "domain" {
}
variable "namespace" {
}
variable "ingress_class" {
}
variable "kube_config_file" {
}

provider "kubernetes" {
  load_config_file = "true"
  config_path = var.kube_config_file
}


resource "kubernetes_namespace" "factory" {
  metadata {
    name = var.namespace
  }
}

module "keycloak" {
    source                  = "./keycloak/helm"
    namespace               = kubernetes_namespace.factory.metadata[0].name
    kube_config_file        = var.kube_config_file

    username                = "keycloak"
    password                = "@dminK#clo@k"

    ingress_host            = "kc.${var.domain}"
    ingress_class           = var.ingress_class
}
module "realm" {
    source                  = "./keycloak/realm"
    keycloak_realm          = "kathra"

    keycloak_client_id      = "admin-cli"
    keycloak_username       = "keycloak"
    keycloak_password       = "@dminK#clo@k"
    keycloak_url            = module.keycloak.url
}

module "gitlab_client" {
    source                  = "./keycloak/client"

    realm                   = module.realm.name
    client_id               = "gitlab"
    redirect_uri            = "https://gitlab.${var.domain}/oidc/callback"
    
    keycloak_client_id      = "admin-cli"
    keycloak_username       = "keycloak"
    keycloak_password       = "@dminK#clo@k"
    keycloak_url            = module.keycloak.url
}

module "gitlab" {
    source                  = "./gitlab"
    kube_config_file        = var.kube_config_file

    ingress_host            = "gitlab.${var.domain}"
    ingress_class           = var.ingress_class

    namespace               = kubernetes_namespace.factory.metadata[0].name
    password                = "d3f40ltp4ss"

    oidc_url                = module.keycloak.url
    oidc_client_id          = module.gitlab_client.client_id
    oidc_client_secret      = module.gitlab_client.client_secret
}


module "harbor_client" {
    source                  = "./keycloak/client"

    realm                   = module.realm.name
    client_id               = "harbor"
    redirect_uri            = "https://harbor.${var.domain}/oidc/callback"
    
    keycloak_client_id      = "admin-cli"
    keycloak_username       = "keycloak"
    keycloak_password       = "@dminK#clo@k"
    keycloak_url            = module.keycloak.url
}


module "jenkins_client" {
    source                  = "./keycloak/client"

    realm                   = module.realm.name
    client_id               = "jenkins"
    redirect_uri            = "https://jenkins.${var.domain}/oidc/callback"
    
    keycloak_client_id      = "admin-cli"
    keycloak_username       = "keycloak"
    keycloak_password       = "@dminK#clo@k"
    keycloak_url            = module.keycloak.url
}

module "kathra_client" {
    source                  = "./keycloak/client"
    
    realm                   = module.realm.name
    client_id               = "kathra"
    redirect_uri            = "https://dashboard.${var.domain}/oidc/callback"
    
    keycloak_client_id      = "admin-cli"
    keycloak_username       = "keycloak"
    keycloak_password       = "@dminK#clo@k"
    keycloak_url            = module.keycloak.url
}