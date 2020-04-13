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

variable "domain" {
}
variable "k8s_client_id" {
}
variable "k8s_client_secret" { 
}
variable "k8s_version" {
    default = "1.15.10"
}

provider "azurerm" {
    version = "=2.2.0"
    features {}
}

resource "azurerm_resource_group" "kathra" {
    location  = var.location
    name      = var.group
}

module "static_ip" {
    source              = "../public-ip/azure"
    location            = var.location
    group               = azurerm_resource_group.kathra.name
    domain              = var.domain
}

module "kubernetes" {
    source              = "../kubernetes/azure"
    location            = var.location
    group               = azurerm_resource_group.kathra.name
    node_count          = var.k8s_node_count
    node_size           = var.k8s_node_size
    k8s_client_id       = var.k8s_client_id
    k8s_client_secret   = var.k8s_client_secret
    kubernetes_version  = var.k8s_version
}

resource "local_file" "kube_config" {
    content             = module.kubernetes.kube_config
    filename            = "kube_config"
}

module "kubernetes_addons" {
    source              = "../kubernetes_addons"
    kube_config_file    = local_file.kube_config.filename
    public_ip           = module.static_ip.public_ip_address
    aks_group           = azurerm_resource_group.kathra.name
}

module "factory" {
    source              = "../factory"
    ingress_class       = module.kubernetes_addons.ingress_controller
    domain              = var.domain
    namespace           = "factory"
    kube_config_file    = local_file.kube_config.filename
}


output "kubeconfig_file" {
    value               = local_file.kube_config.filename
}
output "kubeconfig_content" {
    value               = module.kubernetes.kube_config
}