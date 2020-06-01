

####################
### INPUT
####################
variable "domain" {
}
variable "kathra_version" {
}
variable "ingress_controller" {
}
variable "ingress_cert_manager_issuer" {
}
variable "kube_config" {
}

####################
### NAMESPACES
####################
resource "kubernetes_namespace" "factory" {
    metadata {
        name = "kathra-factory"
    }
}
resource "kubernetes_namespace" "kathra" {
    metadata {
        name = "kathra-services"
    }
}



####################
### FACTORY
####################
module "factory" {
    source                      = "./kathra-factory"
    ingress_class               = var.ingress_controller
    ingress_cert_manager_issuer = var.ingress_cert_manager_issuer
    domain                      = var.domain
    namespace                   = kubernetes_namespace.factory.metadata[0].name
    kube_config                 = var.kube_config
    deploymanager               = {
        tag = var.kathra_version
    }
}

####################
### SERVICES
####################
module "services" {
    source                      = "./kathra-services"
    namespace                   = kubernetes_namespace.kathra.metadata[0].name
    
    kathra = {
        images = {
            registry_url    = "registry.hub.docker.com"
            root_repository = "kathra"
            docker_conf     = ""
            tag             = var.kathra_version
        }
        domain   = var.domain
        ingress  = {
            class                   = var.ingress_controller
            cert-manager_issuer     = var.ingress_cert_manager_issuer
            appmanager = {
                host                = "appmanager.${var.domain}"
                tls_secret_name     = "appmanager-cert"
            }
            dashboard = {
                host                = "dashboard.${var.domain}"
                tls_secret_name     = "dashboard-cert"
            }
            platformmanager = {
                host                = "platformmanager.${var.domain}"
                tls_secret_name     = "platformmanager-cert"
            }
        }
        arangodb = {
            password                = "dezofzeofo"
        }
        oidc = {
            client_id               = module.factory.kathra.client_id
            client_secret           = module.factory.kathra.client_secret
        }
    }

    gitlab                      = {
        url          = module.factory.gitlab.url
        username     = module.factory.user_sync.username
        password     = module.factory.user_sync.password
        token        = module.factory.user_sync.gitlab_api_token
        root_project = "kathra-projects"
    }

    jenkins                      = {
        url          = module.factory.jenkins.url
        username     = module.factory.user_sync.username
        token        = module.factory.user_sync.jenkins_api_token
    }

    harbor                      = {
        url          = module.factory.harbor.url
        username     = module.factory.user_sync.username
        password     = module.factory.user_sync.password
    }

    nexus                         = module.factory.nexus

    keycloak                      = {
        url           = module.factory.keycloak.url
        user          = {
            auth_url      = "${module.factory.keycloak.url}/auth"
            realm         = module.factory.realm.name
            username      = module.factory.user_sync.username
            password      = module.factory.user_sync.password
        }
        admin          = {
            auth_url      = "${module.factory.keycloak.url}/auth"
            username      = module.factory.keycloak.username
            password      = module.factory.keycloak.password
            realm         = "master"
            client_id     = "admin-cli"
        }
    }
}


####################
### OUTPUT
####################
output "factory" {
    value = module.factory
}
output "services" {
    value = module.services
}