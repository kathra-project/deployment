

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
variable "factory_namespace" {
}
variable "factory_tls_secret_name" {
    default = null
}
variable "services_namespace" {
}
variable "services_tls_secret_name" {
    default = null
}
variable "password_db" {
    default = null
}

resource "random_password" "password_db" {
    count = (var.password_db == null) ? 1 : 0
    length = 16
    special = false
}

data "local_file" "identities" {
    filename = "${path.module}/identities.yml"
}


####################
### FACTORY
####################
module "factory" {
    source                      = "./kathra-factory"
    ingress_class               = var.ingress_controller
    ingress_cert_manager_issuer = var.ingress_cert_manager_issuer
    ingress_tls_secret_name     = var.factory_tls_secret_name
    domain                      = var.domain
    namespace                   = var.factory_namespace
    kube_config                 = var.kube_config
    deploymanager               = {
        tag = var.kathra_version
    }
    keycloak                    = {
        host_prefix   = "keycloak"
        username      = "keycloak"
        password      = "P@sswo=03dToUpd4t3"
        client_id     = "admin-cli"
    }
    identities                  =   yamldecode(data.local_file.identities.content)
}

####################
### SERVICES
####################
module "services" {
    source                      = "./kathra-services"
    namespace                   = var.services_namespace
    
    kathra = {
        images = {
            registry_url    = ""
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
                tls_secret_name     = var.services_tls_secret_name != null ? var.services_tls_secret_name : "appmanager-cert"
            }
            dashboard = {
                host                = "dashboard.${var.domain}"
                tls_secret_name     = var.services_tls_secret_name != null ? var.services_tls_secret_name : "dashboard-cert"
            }
            resourcemanager = {
                host                = "resourcemanager.${var.domain}"
                tls_secret_name     = var.services_tls_secret_name != null ? var.services_tls_secret_name : "resourcemanager-cert"
            }
            sourcemanager = {
                host                = "sourcemanager.${var.domain}"
                tls_secret_name     = var.services_tls_secret_name != null ? var.services_tls_secret_name : "sourcemanager-cert"
            }
            pipelinemanager = {
                host                = "pipelinemanager.${var.domain}"
                tls_secret_name     = var.services_tls_secret_name != null ? var.services_tls_secret_name : "pipelinemanager-cert"
            }
            platformmanager = {
                host                = "platformmanager.${var.domain}"
                tls_secret_name     = var.services_tls_secret_name != null ? var.services_tls_secret_name : "platformmanager-cert"
            }
        }
        arangodb = {
            password                = (var.password_db == null) ? random_password.password_db[0].result : var.password_db
        }
        oidc = {
            client_id               = module.factory.kathra.client_id
            client_secret           = module.factory.kathra.client_secret
        }
    }

    gitlab                      = {
        url          = module.factory.gitlab.url
        username     = module.factory.kathra_service_account.username
        password     = module.factory.kathra_service_account.password
        token        = module.factory.kathra_service_account.gitlab_api_token
        root_project = "kathra-projects"
    }

    jenkins                      = {
        url          = module.factory.jenkins.url
        username     = module.factory.kathra_service_account.username
        token        = module.factory.kathra_service_account.jenkins_api_token
    }

    harbor                      = {
        url          = module.factory.harbor.url
        username     = module.factory.harbor.admin.username
        password     = module.factory.harbor.admin.password
    }

    nexus                         = module.factory.nexus

    keycloak                      = {
        url           = module.factory.keycloak.url
        user          = {
            auth_url      = "${module.factory.keycloak.url}/auth"
            realm         = module.factory.realm.name
            username      = module.factory.kathra_service_account.username
            password      = module.factory.kathra_service_account.password
        }
        admin          = {
            auth_url      = "${module.factory.keycloak.url}/auth"
            username      = module.factory.keycloak.admin.username
            password      = module.factory.keycloak.admin.password
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
output "domain" {
    value = var.domain
}