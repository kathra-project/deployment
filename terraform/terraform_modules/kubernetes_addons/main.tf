
variable "kube_config" {
}
variable "public_ip" {
}
variable "aks_group" {
    default = ""
}

provider "helm" {
  kubernetes {
    load_config_file       = "false"
    host                   = var.kube_config.host
    client_certificate     = base64decode(var.kube_config.client_certificate)
    client_key             = base64decode(var.kube_config.client_key)
    cluster_ca_certificate = base64decode(var.kube_config.cluster_ca_certificate)
  }
}
provider "kubernetes" {
    load_config_file       = "false"
    host                   = var.kube_config.host
    client_certificate     = base64decode(var.kube_config.client_certificate)
    client_key             = base64decode(var.kube_config.client_key)
    cluster_ca_certificate = base64decode(var.kube_config.cluster_ca_certificate)
}

module "kubedb" {
    source              = "../helm-packages/kubedb"
}

module "treafik" {
    source              = "../helm-packages/traefik"
    load_balancer_ip    = var.public_ip
    aks_group           = var.aks_group
}

module "cert-manager" {
    source              = "../helm-packages/cert-manager"
    kube_config         = var.kube_config
    namespace           = module.treafik.namespace
}

output "ingress_controller" {
    value = module.treafik.ingress_controller
}
output "ingress_cert_manager_issuer" {
    value = module.cert-manager.issuer
}
