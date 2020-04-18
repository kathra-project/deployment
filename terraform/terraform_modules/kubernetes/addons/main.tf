
variable "kube_config_file" {
  
}
variable "load_balancer_azure_group" {
    default = ""
}
variable "static_ip" {
  
}



module "traefik_namespace" {
    source              = "../../kubernetes/namespace"
    namespace           = "traefik"
    kube_config_file    = var.kube_config_file
}
module "kubedb_namespace" {
    source              = "../../kubernetes/namespace"
    namespace           = "kubedb"
    kube_config_file    = var.kube_config_file
}

module "treafik" {
    source                      = "../../helm-packages/traefik"
    namespace                   = module.traefik_namespace.namespace
    kube_config_file            = var.kube_config_file
    load_balancer_ip            = var.static_ip
    load_balancer_azure_group   = var.load_balancer_azure_group
}

module "kubedb" {
    source              = "../../helm-packages/kubedb"
    kube_config_file    = var.kube_config_file
    namespace           = module.kubedb_namespace.namespace
}

module "cert-manager" {
    source              = "../../helm-packages/cert-manager"
    kube_config_file    = var.kube_config_file
    namespace           = module.treafik.namespace
}

