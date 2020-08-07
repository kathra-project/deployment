variable "domain" {
}
variable "tls_cert_filepath" {
    default = null
}
variable "tls_key_filepath" {
    default = null
}
variable "kube_config" {
    default = {
        host                    = null
        client_certificate      = null
        client_key              = null
        cluster_ca_certificate  = null
    }
}
variable "kathra_version" {
    default = "latest"
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


provider "kubernetes" {
    load_config_file       = "false"
    host                   = var.kube_config.host
    client_certificate     = base64decode(var.kube_config.client_certificate)
    client_key             = base64decode(var.kube_config.client_key)
    cluster_ca_certificate = base64decode(var.kube_config.cluster_ca_certificate)
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


provider "kubectl" {
    load_config_file       = false
    host                   = var.kube_config.host
    client_certificate     = base64decode(var.kube_config.client_certificate)
    client_key             = base64decode(var.kube_config.client_key)
    cluster_ca_certificate = base64decode(var.kube_config.cluster_ca_certificate)
    apply_retry_count      = 15
}


############################################################
### ACME 
############################################################
provider "acme" {
    version     = "1.2.1"
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

output "acme" {
    value = {
        "tls_private_key"   = tls_private_key.private_key[0]
        "cert"              = acme_certificate.certificate[0]
        "key"               = acme_certificate.certificate[0]
    }
}

############################################################
### STORAGE CLASS 
############################################################
resource "kubernetes_storage_class" "default" {
    metadata {
        name = "default"
    }
    storage_provisioner = "k8s.io/minikube-hostpath"
    reclaim_policy      = "Delete"
}

############################################################
### KATHRA INSTANCE
############################################################
module "namespace_factory_with_tls" {
    source            = "./namespace_with_tls"
    namespace         = "kathra-factory"
    default_tls_cert  = (var.acme_provider == null) ? file(var.tls_cert_filepath) : base64encode(acme_certificate.certificate[0].certificate_pem)
    default_tls_key   = (var.acme_provider == null) ? file(var.tls_key_filepath)  : base64encode(acme_certificate.certificate[0].private_key_pem)
}

module "namespace_kathra_with_tls" {
    source            = "./namespace_with_tls"
    namespace         = "kathra-services"
    default_tls_cert  = (var.acme_provider == null) ? file(var.tls_cert_filepath) : base64encode(acme_certificate.certificate[0].certificate_pem) 
    default_tls_key   = (var.acme_provider == null) ? file(var.tls_key_filepath)  : base64encode(acme_certificate.certificate[0].private_key_pem)
}


module "kathra" {
    source                      = "../kathra"
    kathra_version              = var.kathra_version
    ingress_controller          = "nginx"
    ingress_cert_manager_issuer = ""
    domain                      = var.domain
    kube_config                 = var.kube_config

    factory_namespace           = module.namespace_factory_with_tls.name
    factory_tls_secret_name     = module.namespace_factory_with_tls.tls_secret_name
    
    services_namespace          = module.namespace_kathra_with_tls.name
    services_tls_secret_name    = module.namespace_kathra_with_tls.tls_secret_name
}

output "kathra" {
    value = module.kathra
}
