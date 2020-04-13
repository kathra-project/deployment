
variable "kube_config_file" {
}
variable "public_ip" {
}
variable "aks_group" {
    default = ""
}


module "kubedb" {
    source              = "../helm-packages/kubedb"
    kube_config_file    = var.kube_config_file
}

module "treafik" {
    source              = "../helm-packages/traefik"
    kube_config_file    = var.kube_config_file
    load_balancer_ip    = var.public_ip
    aks_group           = var.aks_group
}

module "cert-manager" {
    source              = "../helm-packages/cert-manager"
    kube_config_file    = var.kube_config_file
    namespace           = module.treafik.namespace
}

output "ingress_controller" {
    value = module.treafik.ingress_controller
}