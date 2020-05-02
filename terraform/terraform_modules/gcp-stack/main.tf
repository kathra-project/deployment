variable "gcp_crendetials" {
}
variable "project_name" {
}
variable "region" {
}
variable "zone" {
}
variable "domain" {
}


provider "google" {
    version     = "3.14.0"
    credentials = file(var.gcp_crendetials)
    project     = var.project_name
    region      = var.region
    zone        =  var.zone
}

module "kubernetes" {
    source              = "../kubernetes/gcp"
    project_name        = var.project_name
    location            = var.region
}
module "kubeconfig" {
    source              = "../kubeconfig"
    kube_config         = module.kubernetes.kube_config
}


module "static_ip" {
    source              = "../public-ip/gcp"
    domain              = var.domain
}

resource "local_file" "kube_config" {
    content             = module.kubeconfig.kube_config_raw
    filename            = "kube_config"
}

module "kubernetes_addons" {
    source              = "../kubernetes_addons"
    kube_config         = module.kubernetes.kube_config
    kube_config_file    = local_file.kube_config.filename
    public_ip           = module.static_ip.public_ip_address
    aks_group           = azurerm_resource_group.kathra.name
}

module "factory" {
    source                      = "../factory"
    ingress_class               = module.kubernetes_addons.ingress_controller
    domain                      = var.domain
    namespace                   = "factory"
    kube_config                 = module.kubernetes.kube_config
    kube_config_raw             = module.kubernetes.kube_config_raw
}

output "kubernetes" {
    value = module.kubernetes
}
output "kubeconfig_path" {
    value = module.kubernetes.kubeconfig_path
}
