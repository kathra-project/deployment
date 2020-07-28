

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
<<<<<<< HEAD
variable "kube_config_file" {
}
variable "ingress_controller" {
  default = "traefik"
}

resource "null_resource" "kathraInstaller" {
  provisioner "local-exec" {
    command = <<EOT
      echo "CONFIG:$CONFIG"
      echo "DOMAIN:$DOMAIN"
      echo "CHARTS_VERSION:$CHARTS_VERSION"
      echo "IMAGES_TAG:$IMAGES_TAG"
      export KUBECONFIG="$(pwd)/$CONFIG"

      [ -d /tmp/kathra-deployment-tf ] && rm -rf /tmp/kathra-deployment-tf
      git clone https://gitlab.com/kathra/deployment.git /tmp/kathra-deployment-tf || exit 1
      cd /tmp/kathra-deployment-tf && git checkout $CHARTS_VERSION || exit 1
      /tmp/kathra-deployment-tf/install.sh --domain=$DOMAIN --chart-version=$CHARTS_VERSION --kathra-image-tag=$IMAGES_TAG --enable-tls-ingress --verbose || exit 1
   EOT
    environment = {
      CONFIG = var.kube_config_file
      CHARTS_VERSION = var.charts_version
      IMAGES_TAG = var.images_tag
      DOMAIN = var.domain
=======
variable "services_namespace" {
}
variable "services_tls_secret_name" {
    default = null
}
variable "passwordDb" {
    default = "dezofzeofo"
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
>>>>>>> feature/factory_tf
    }
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
            password                = var.passwordDb
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
        username     = module.factory.harbor.username
        password     = module.factory.harbor.password
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
output "domain" {
    value = var.domain
}