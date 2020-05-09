variable "kube_config" {
}
variable "default_tls_cert" {
}
variable "default_tls_key" {
}

provider "helm" {
  kubernetes {
    load_config_file            = "false"
    host                        = var.kube_config.host
    client_certificate          = base64decode(var.kube_config.client_certificate)
    client_key                  = base64decode(var.kube_config.client_key)
    cluster_ca_certificate      = base64decode(var.kube_config.cluster_ca_certificate)
  }
}
provider "kubernetes" {
    load_config_file          = "false"
    host                      = var.kube_config.host
    client_certificate        = base64decode(var.kube_config.client_certificate)
    client_key                = base64decode(var.kube_config.client_key)
    cluster_ca_certificate    = base64decode(var.kube_config.cluster_ca_certificate)
}

module "kubedb" {
    source                     = "../../helm-packages/kubedb"
}

module "treafik" {
    source                     = "./traefik"
    default_tls_key            = var.default_tls_key
    default_tls_cert           = var.default_tls_cert
}

/*
resource "null_resource" "forward_port" {
    provisioner "local-exec" {
        command = <<EOT
            . ${path.module}/../sh/functions.sh
            forwardPort "80" "$(minikube ip)" "$nodePortHTTP"   || exit 1
            forwardPort "443" "$(minikube ip)" "$nodePortHTTPS" || exit 1
        EOT
        interpreter = ["bash", "-c"]
        environment = {
            nodePortHTTP            = module.treafik.http_node_port
            nodePortHTTPS           = module.treafik.https_node_port
            debug                   = 1
        }
    }
}
*/
output "treafik" {
    value = module.treafik
}

output "ingress_controller" {
    value = module.treafik.ingress_controller
}
output "ingress_cert_manager_issuer" {
    value = ""
}
