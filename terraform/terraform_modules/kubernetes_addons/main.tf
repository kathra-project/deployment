
variable "public_ip" {
}
variable "aks_group" {
    default = ""
}
variable "domain" {
}

module "treafik" {
    source              = "../helm-packages/traefik"
    load_balancer_ip    = var.public_ip
    aks_group           = var.aks_group
}

module "cert-manager" {
    source              = "../helm-packages/cert-manager"
    namespace           = module.treafik.namespace
}


resource "kubernetes_namespace" "monitoring" {
    metadata {
        name = "monitoring"
    }
}

module "prometheus" {
    source                      = "../helm-packages/prometheus"
    namespace                   = kubernetes_namespace.monitoring.metadata[0].name
    ingress_class               = module.treafik.ingress_controller
    ingress_cert_manager_issuer = module.cert-manager.issuer
    grafana                     = {
        ingress_host            = "monitoring.${var.domain}"
        password                = "admin"
        ingress_tls_secret_name = "grafana-cert"
    }
}

output "prometheus" {
  value = module.prometheus
}


output "ingress_controller" {
    value = module.treafik.ingress_controller
}
output "ingress_cert_manager_issuer" {
    value = module.cert-manager.issuer
}
