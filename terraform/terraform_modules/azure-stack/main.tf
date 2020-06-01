

variable "domain" {
}
variable "k8s_client_id" {
}
variable "k8s_client_secret" { 
}
variable "subscribtion_id" {
}
variable "tenant_id" {
}
variable "kathra_version" {
    default = "stable"
}

variable "group" {
    default = "kathra"
}
variable "location" {
    default = "eastus"
}
variable "k8s_node_count" {
    default = 4
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

############################################################
### KUBERNETES ADDONS (INGRESS + CERT MANAGER)
############################################################
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
    domain                      = var.domain
}

provider "kubernetes" {
    load_config_file       = "false"
    host                   = module.kubernetes.kube_config.host
    client_certificate     = base64decode(module.kubernetes.kube_config.client_certificate)
    client_key             = base64decode(module.kubernetes.kube_config.client_key)
    cluster_ca_certificate = base64decode(module.kubernetes.kube_config.cluster_ca_certificate)
}


provider "helm" {
    kubernetes {
        load_config_file       = "false"
        host                   = module.kubernetes.kube_config.host
        client_certificate     = base64decode(module.kubernetes.kube_config.client_certificate)
        client_key             = base64decode(module.kubernetes.kube_config.client_key)
        cluster_ca_certificate = base64decode(module.kubernetes.kube_config.cluster_ca_certificate)
    }
}


provider "kubectl" {
    load_config_file       = false
    host                   = module.kubernetes.kube_config.host
    client_certificate     = base64decode(module.kubernetes.kube_config.client_certificate)
    client_key             = base64decode(module.kubernetes.kube_config.client_key)
    cluster_ca_certificate = base64decode(module.kubernetes.kube_config.cluster_ca_certificate)
    apply_retry_count      = 15
}


############################################################
### KATHRA INSTANCE
############################################################
module "kathra" {
    source                      = "../kathra"
    ingress_controller          = module.kubernetes_addons.ingress_controller
    ingress_cert_manager_issuer = module.kubernetes_addons.ingress_cert_manager_issuer
    domain                      = var.domain
    kathra_version              = var.kathra_version
}

####################
### BACKUP
####################
module "backup" {
    source                  = "./../backup/azure"
    group                   = "${var.group}_backup"
    namespace               = "velero"
    location                = var.location
    tenant_id               = var.tenant_id
    subscribtion_id         = var.subscribtion_id
    velero_client_id        = var.k8s_client_id
    velero_client_secret    = var.k8s_client_secret
}


############################################################
### OUTPUT
############################################################
output "kubeconfig_content" {
    value                       = module.kubernetes.kube_config_raw
}
output "kathra" {
    value                       = module.kathra
}