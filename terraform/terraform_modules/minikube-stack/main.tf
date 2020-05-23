variable "domain" {
}
variable "tls_cert_filepath" {
    default = null
}
variable "tls_key_filepath" {
    default = null
}
variable "kube_config" {
  
}
variable "namespaces_with_tls" {
    default = ["factory","kathra"]
}

variable "acme_provider" {
    default = null
}

variable "acme_config" {
    default = null
}

provider "acme" {
    server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

resource "tls_private_key" "private_key" {
    count                       = (var.acme_provider == null) ? 0 : 1
    algorithm                   = "RSA"
}

resource "acme_registration" "reg" {
    count                       = (var.acme_provider == null) ? 0 : 1
    account_key_pem             = tls_private_key.private_key[0].private_key_pem
    email_address               = "contact@${var.domain}"
}

resource "acme_certificate" "certificate" {
    count                       = (var.acme_provider == null) ? 0 : 1
    account_key_pem             = acme_registration.reg[0].account_key_pem
    dns_challenge {
        provider = var.acme_provider
        config = var.acme_config
    }
    common_name                 = "*.${var.domain}"
}

module "namespace_factory_with_tls" {
    source            = "./namespace_with_tls"
    namespace         = "kathra-factory"
    default_tls_cert  = (var.acme_provider == null) ? file(var.tls_cert_filepath) : acme_certificate.certificate[0].certificate_pem 
    default_tls_key   = (var.acme_provider == null) ? file(var.tls_key_filepath)  : acme_certificate.certificate[0].private_key_pem
}

module "namespace_kathra_with_tls" {
    source            = "./namespace_with_tls"
    namespace         = "kathra-services"
    default_tls_cert  = (var.acme_provider == null) ? file(var.tls_cert_filepath) : acme_certificate.certificate[0].certificate_pem 
    default_tls_key   = (var.acme_provider == null) ? file(var.tls_key_filepath)  : acme_certificate.certificate[0].private_key_pem
}

resource "kubernetes_storage_class" "default" {
    metadata {
        name = "default"
    }
    storage_provisioner = "k8s.io/minikube-hostpath"
    reclaim_policy      = "Delete"
}

module "factory" {
    source                      = "../factory"
    ingress_class               = "nginx"
    ingress_cert_manager_issuer = ""
    ingress_tls_secret_name     = module.namespace_factory_with_tls.tls_secret_name
    domain                      = var.domain
    namespace                   = module.namespace_factory_with_tls.name
    kube_config                 = var.kube_config
}

output "factory" {
    value = module.factory
}
