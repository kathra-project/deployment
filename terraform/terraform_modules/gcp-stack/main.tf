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
variable "node_size" {
  default = "n1-standard-8"
}
variable "node_count" {
  default = 2
}
variable "kathra_version" {
  default = "latest"
}



provider "google" {
    version     = "3.23.0"
    credentials = file(var.gcp_crendetials)
    project     = var.project_name
    region      = var.region
    zone        = var.zone
}

module "kubernetes" {
    source              = "../kubernetes/gcp"
    project_name        = var.project_name
    location            = var.region
    node_size           = var.node_size
    node_count          = var.node_count
}


module "static_ip" {
    source              = "../public-ip/gcp"
    domain              = var.domain
}

provider "kubernetes" {
    load_config_file       = "false"
    host                   = module.kubernetes.kube_config.host
    username               = module.kubernetes.kube_config.username
    password               = module.kubernetes.kube_config.password
    client_certificate     = base64decode(module.kubernetes.kube_config.client_certificate)
    client_key             = base64decode(module.kubernetes.kube_config.client_key)
    cluster_ca_certificate = base64decode(module.kubernetes.kube_config.cluster_ca_certificate)
}


provider "helm" {
    kubernetes {
        load_config_file       = "false"
        host                   = module.kubernetes.kube_config.host
        username               = module.kubernetes.kube_config.username
        password               = module.kubernetes.kube_config.password
        client_certificate     = base64decode(module.kubernetes.kube_config.client_certificate)
        client_key             = base64decode(module.kubernetes.kube_config.client_key)
        cluster_ca_certificate = base64decode(module.kubernetes.kube_config.cluster_ca_certificate)
    }
}

provider "kubectl" {
    load_config_file       = false
    host                   = module.kubernetes.kube_config.host
    username               = module.kubernetes.kube_config.username
    password               = module.kubernetes.kube_config.password
    client_certificate     = base64decode(module.kubernetes.kube_config.client_certificate)
    client_key             = base64decode(module.kubernetes.kube_config.client_key)
    cluster_ca_certificate = base64decode(module.kubernetes.kube_config.cluster_ca_certificate)
    apply_retry_count      = 15
}


resource "kubernetes_storage_class" "default" {
    metadata {
        name = "default"
    }
    storage_provisioner = "kubernetes.io/gce-pd"
    reclaim_policy      = "Retain"
    parameters = {
        type = "pd-standard"
    }
    depends_on = [ module.kubernetes ]
}

############################################################
### KUBERNETES ADDONS (INGRESS + CERT MANAGER)
############################################################
module "kubernetes_addons" {
    source              = "../kubernetes_addons"
    public_ip           = module.static_ip.public_ip_address
    domain              = var.domain
}

############################################################
### KATHRA INSTANCE
############################################################
resource "kubernetes_namespace" "factory" {
    metadata {
        name = "kathra-factory"
    }
}
resource "kubernetes_namespace" "services" {
    metadata {
        name = "kathra-services"
    }
}
module "kathra" {
    source                      = "../kathra"
    ingress_controller          = module.kubernetes_addons.ingress_controller
    ingress_cert_manager_issuer = module.kubernetes_addons.ingress_cert_manager_issuer
    domain                      = var.domain
    kathra_version              = var.kathra_version
    kube_config                 = module.kubernetes.kube_config
    factory_namespace           = kubernetes_namespace.factory.metadata[0].name
    services_namespace          = kubernetes_namespace.services.metadata[0].name
}

############################################################
### OUTPUT
############################################################

module "kube_config" {
    source                      = "../kubeconfig"
    kube_config                 = module.kubernetes.kube_config
}


output "kubernetes" {
    value                       = module.kubernetes
}

output "kubeconfig_content" {
    value                       = module.kube_config.kube_config_raw
}

output "kathra" {
    value                       = module.kathra
}
