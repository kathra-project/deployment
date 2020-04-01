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

module "static_ip" {
    source              = "../public-ip/gcp"
    domain              = var.domain
}
/*
module "kubedb" {
    source              = "../helm-packages/kubedb"
    kube_config_file    = module.kubernetes.kubeconfig_path
    tiller_ns           = module.kubernetes.tiller_ns
}
*/
module "treafik" {
    source              = "../helm-packages/traefik"
    kube_config_file    = module.kubernetes.kubeconfig_path
    load_balancer_ip    = module.static_ip.public_ip_address
    tiller_ns           = module.kubernetes.tiller_ns
    group               = ""
}

module "cert-manager" {
    source              = "../helm-packages/cert-manager"
    kube_config_file    = module.kubernetes.kubeconfig_path
    namespace           = module.treafik.namespace
    tiller_ns           = module.kubernetes.tiller_ns
}

output "kubernetes" {
    value = module.kubernetes
}
output "kubeconfig_path" {
    value = module.kubernetes.kubeconfig_path
}
