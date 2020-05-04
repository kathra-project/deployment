

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
    default = "East US"
}
variable "k8s_node_count" {
    default = 1
}
variable "k8s_node_size" {
    default = "Standard_DS3_v2"
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

output "kubeconfig_content" {
    value                       = module.kubernetes.kube_config_raw
}
output "kubeconfig" {
    value                       = module.kubernetes.kube_config
}