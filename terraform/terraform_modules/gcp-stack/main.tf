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
variable "k8s_version" {
    default = "1.15.10"
}
variable "k8s_node_count" {
    default = 4
}
variable "k8s_node_type" {
    default = "n1-standard-4"
}


provider "google" {
    version     = "3.14.0"
    credentials = file(var.gcp_crendetials)
    project     = var.project_name
    region      = var.region
    zone        = var.zone
}

module "kubernetes" {
    source              = "../kubernetes/gcp"
    project_name        = var.project_name
    location            = var.region
    kubernetes_version  = var.k8s_version
    node_count          = var.k8s_node_count
    node_type           = var.k8s_node_type
}


module "static_ip" {
    source              = "../public-ip/gcp"
    domain              = var.domain
}

resource "local_file" "kube_config" {
    content             = module.kubernetes.kubeconfig_content
    filename            = "kube_config"
}

module "kubernetes_addons" {
    source              = "../kubernetes/addons"
    kube_config_file    = local_file.kube_config.filename
    static_ip           = module.static_ip.public_ip_address
}

output "kubeconfig_content" {
    value = module.kubernetes.kubeconfig_content
}
output "kubeconfig_path" {
    value = local_file.kube_config.filename
}
