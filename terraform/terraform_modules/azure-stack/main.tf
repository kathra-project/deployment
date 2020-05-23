

variable "domain" {
}
variable "k8s_client_id" {
}
variable "k8s_client_secret" { 
}

variable "group" {
    default = "kathra"
}
variable "location" {
    default = "eastus"
}
variable "k8s_node_count" {
    default = 3
}
variable "k8s_node_size" {
    default = "Standard_D4s_v3"
}
variable "k8s_version" {
    default = "1.15.10"
}

provider "azurerm" {
    version = "=2.2.0"
    features {}
}

resource "azurerm_resource_group" "kathra" {
    location                    = var.location
    name                        = var.group
}

module "static_ip" {
    source                      = "../public-ip/azure"
    location                    = var.location
    group                       = azurerm_resource_group.kathra.name
    domain                      = var.domain
}

module "kubernetes" {
    source                      = "../kubernetes/azure"
    location                    = var.location
    group                       = azurerm_resource_group.kathra.name
    node_count                  = var.k8s_node_count
    node_size                   = var.k8s_node_size
    k8s_client_id               = var.k8s_client_id
    k8s_client_secret           = var.k8s_client_secret
    kubernetes_version          = var.k8s_version
}

module "kubernetes_addons" {
    source                      = "../kubernetes_addons"
    kube_config                 = module.kubernetes.kube_config
    public_ip                   = module.static_ip.public_ip_address
    aks_group                   = azurerm_resource_group.kathra.name
}

provider "kubernetes" {
    load_config_file       = "false"
    host                   = module.kubernetes.kube_config.host
    client_certificate     = base64decode(module.kubernetes.kube_config.client_certificate)
    client_key             = base64decode(module.kubernetes.kube_config.client_key)
    cluster_ca_certificate = base64decode(module.kubernetes.kube_config.cluster_ca_certificate)
}

resource "kubernetes_namespace" "factory" {
  metadata {
    name = "kathra-factory"
  }
}

module "factory" {
    source                      = "../factory"
    ingress_class               = module.kubernetes_addons.ingress_controller
    ingress_cert_manager_issuer = module.kubernetes_addons.ingress_cert_manager_issuer
    domain                      = var.domain
    namespace                   = kubernetes_namespace.factory.metadata[0].name
    kube_config                 = module.kubernetes.kube_config
}


resource "kubernetes_namespace" "kathra" {
  metadata {
    name = "kathra-services"
  }
}

module "kathra" {
    source                      = "../kathra"
    namespace                   = kubernetes_namespace.kathra.metadata[0].name
    kube_config                 = module.kubernetes.kube_config

    kathra = {
        images = {
            registry_url    = "registry.hub.docker.com"
            root_repository = "kathra"
            docker_conf     = ""
            tag             = "stable"
        }
        domain   = var.domain
        ingress  = {
            class                 = module.kubernetes_addons.ingress_controller
            cert-manager_issuer   = module.kubernetes_addons.ingress_cert_manager_issuer
            appmanager = {
                host              = "appmanager.${var.domain}"
                tls_secret_name   = "appmanager-cert"
            }
            dashboard = {
                host              = "dashboard.${var.domain}"
                tls_secret_name   = "dashboard-cert"
            }
            platformmanager = {
                host              = "platformmanager.${var.domain}"
                tls_secret_name   = "platformmanager"
            }
        }
        arangodb = {
            password  = "dezofzeofo"
        }
        oidc = {
            client_id       = module.factory.kathra.client_id
            client_secret   = module.factory.kathra.client_secret
        }
    }

    gitlab                      = {
        url          = module.factory.gitlab.url
        username     = module.factory.user_sync.username
        password     = module.factory.user_sync.password
        token        = module.factory.user_sync.gitlab_api_token
        root_project = "kathra-projects"
    }

    harbor                      = {
        url          = module.factory.harbor.url
        username     = module.factory.user_sync.username
        password     = module.factory.user_sync.password
    }

    jenkins                      = {
        url          = module.factory.harbor.url
        username     = module.factory.user_sync.username
        token        = module.factory.user_sync.jenkins_api_token
    }

    nexus                         = module.factory.nexus

    keycloak                      = {
        url           = module.factory.keycloak.url
        user          = {
            auth_url      = "${module.factory.keycloak.url}/auth"
            realm         = module.factory.realm.name
            username      = module.factory.user_sync.username
            password      = module.factory.user_sync.password
        }
        admin          = {
            auth_url      = "${module.factory.keycloak.url}/auth"
            username      = module.factory.user_sync.username
            password      = module.factory.user_sync.password
            realm         = "master"
            client_id     = "admin-cli"
        }
    }
}


output "kubeconfig_content" {
    value                       = module.kubernetes.kube_config_raw
}
output "factory" {
    value                       = module.factory
}