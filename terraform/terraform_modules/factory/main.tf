

variable "factory_namespace" {
  
}

module "traefik_namespace" {
    source              = "../kubernetes/namespace"
    namespace           = var.traefik_namespace
    kube_config_file    = local_file.kube_config.filename
}

module "keycloak" {
    source              = "../helm-packages/keycloak"
    namespace           = module.traefik_namespace.namespace
    kube_config_file    = local_file.kube_config.filename
}