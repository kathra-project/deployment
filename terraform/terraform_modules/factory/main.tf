variable "domain" {
}
variable "namespace" {
}
variable "ingress_tls_secret_name" {
    default = null
}
variable "ingress_class" {
}
variable "ingress_cert_manager_issuer" {
}
variable "kube_config" {
}

variable "keycloak" {
    default = {
        host_prefix   = "keycloak"
        username      = "keycloak"
        password      = "BTg1Dmda2gyzUwvdZh3N"
        client_id     = "admin-cli"
    }
}
variable "jenkins" {
    default = {
        host_prefix   = "jenkins"
        password      = "BTg1Dmda2gyzUwvdZh3N"
    }
}
variable "nexus" {
    default = {
        host_prefix   = "nexus"
        password      = "BTg1Dmda2gyzUwvdZh3N"
    }
}
variable "harbor" {
    default = {
        host_prefix   = "harbor"
        password      = "BTg1Dmda2gyzUwvdZh3N"
    }
}
variable "gitlab" {
    default = {
        host_prefix   = "gitlab"
        password      = "BTg1Dmda2gyzUwvdZh3N"
    }
}
variable "sonarqube" {
    default = {
        host_prefix   = "sonarqube"
        password      = "BTg1Dmda2gyzUwvdZh3N"
    }
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

/****************************
    KEYCLOAK
****************************/
module "keycloak" {
    source                      = "./keycloak/helm"
    namespace                   = var.namespace
    kube_config                 = var.kube_config

    username                    = var.keycloak.username
    password                    = var.keycloak.password

    ingress_host                = "${var.keycloak.host_prefix}.${var.domain}"
    ingress_class               = var.ingress_class
    ingress_cert_manager_issuer = var.ingress_cert_manager_issuer
    ingress_tls_secret_name     = var.ingress_tls_secret_name
}
output "keycloak" {
    value = module.keycloak
}

module "realm" {
    source                  = "./keycloak/realm"
    keycloak_realm          = "kathra"

    keycloak_client_id      = var.keycloak.client_id
    keycloak_username       = var.keycloak.username
    keycloak_password       = var.keycloak.password
    keycloak_url            = module.keycloak.url

    first_group_name        = "my-team"
    first_user_login        = "user"
    first_user_password     = "123"
}

output "realm" {
    value = module.realm
}

/****************************
    GITLAB
****************************/
module "gitlab_client" {
    source                  = "./keycloak/client"

    realm                   = module.realm.name
    client_id               = "gitlab"
    redirect_uri            = "https://${var.gitlab.host_prefix}.${var.domain}/*"
    
    keycloak_client_id      = var.keycloak.client_id
    keycloak_username       = var.keycloak.username
    keycloak_password       = var.keycloak.password
    keycloak_url            = module.keycloak.url
}

module "gitlab" {
    source                      = "./gitlab"

    ingress_host                = "${var.gitlab.host_prefix}.${var.domain}"
    ingress_class               = var.ingress_class
    ingress_cert_manager_issuer = var.ingress_cert_manager_issuer
    ingress_tls_secret_name     = {
        unicorn     = var.ingress_tls_secret_name
        minio       = var.ingress_tls_secret_name
        registry    = var.ingress_tls_secret_name
    }

    namespace                   = var.namespace
    password                    = var.gitlab.password

    oidc_url                    = "${module.keycloak.url}/auth/realms/${module.realm.name}"
    oidc_client_id              = module.gitlab_client.client_id
    oidc_client_secret          = module.gitlab_client.client_secret
}

output "gitlab" {
    value = module.gitlab
}


/****************************
    HARBOR
****************************/
module "harbor_client" {
    source                  = "./keycloak/client"

    realm                   = module.realm.name
    client_id               = "harbor"
    redirect_uri            = "https://${var.harbor.host_prefix}.${var.domain}/*"
    
    keycloak_client_id      = var.keycloak.client_id
    keycloak_username       = var.keycloak.username
    keycloak_password       = var.keycloak.password
    keycloak_url            = module.keycloak.url
}
module "harbor" {
    source                      = "./harbor"

    ingress_host                = "${var.harbor.host_prefix}.${var.domain}"
    ingress_class               = var.ingress_class
    ingress_cert_manager_issuer = var.ingress_cert_manager_issuer
    ingress_tls_secret_name     = {
        harbor = var.ingress_tls_secret_name
        notary = var.ingress_tls_secret_name
    }

    namespace                   = var.namespace
    password                    = var.harbor.password

    oidc_url                    = "${module.keycloak.url}/auth/realms/${module.realm.name}"
    oidc_client_id              = module.harbor_client.client_id
    oidc_client_secret          = module.harbor_client.client_secret
}
output "harbor" {
    value = module.harbor
}

/****************************
    NEXUS
****************************/
module "nexus" {
    source                      = "./nexus"

    ingress_host                = "${var.nexus.host_prefix}.${var.domain}"
    ingress_class               = var.ingress_class
    ingress_cert_manager_issuer = var.ingress_cert_manager_issuer
    ingress_tls_secret_name     = var.ingress_tls_secret_name

    namespace                   = var.namespace
    password                    = var.nexus.password
}
output "nexus" {
    value = module.nexus
}

/****************************
    NEXUS
****************************/
module "sonarqube_client" {
    source                  = "./keycloak/client"

    realm                   = module.realm.name
    client_id               = "sonarqube"
    redirect_uri            = "https://${var.sonarqube.host_prefix}.${var.domain}/*"
    
    keycloak_client_id      = var.keycloak.client_id
    keycloak_username       = var.keycloak.username
    keycloak_password       = var.keycloak.password
    keycloak_url            = module.keycloak.url
}
module "sonarqube" {
    source                      = "./sonarqube"

    ingress_host                = "${var.sonarqube.host_prefix}.${var.domain}"
    ingress_class               = var.ingress_class
    ingress_cert_manager_issuer = var.ingress_cert_manager_issuer
    ingress_tls_secret_name     = var.ingress_tls_secret_name

    namespace                   = var.namespace
    
    oidc_url                    = module.realm.url
    oidc_client_id              = module.sonarqube_client.client_id
    oidc_client_secret          = module.sonarqube_client.client_secret
}
output "sonarqube" {
    value = module.nexus
}

/****************************
    DEPLOYMANAGER
****************************/
module "deploymanager" {
    source                      = "./kathra-deploymanager"
    namespace                   = var.namespace

    tag                         = "master"
    deployment_registry         = {
        host     = module.harbor.host
        username = module.harbor.username
        password = module.harbor.password
    }
}
output "deploymanager" {
    value = module.deploymanager
}

/****************************
    JENKINS
****************************/
module "jenkins_client" {
    source                  = "./keycloak/client"

    realm                   = module.realm.name
    client_id               = "jenkins"
    redirect_uri            = "https://${var.jenkins.host_prefix}.${var.domain}/*"
    
    keycloak_client_id      = var.keycloak.client_id
    keycloak_username       = var.keycloak.username
    keycloak_password       = var.keycloak.password
    keycloak_url            = module.keycloak.url
}

module "jenkins" {
    source                      = "./jenkins"

    ingress_host                = "${var.jenkins.host_prefix}.${var.domain}"
    ingress_class               = var.ingress_class
    ingress_cert_manager_issuer = var.ingress_cert_manager_issuer
    ingress_tls_secret_name     = var.ingress_tls_secret_name

    namespace                   = var.namespace
    password                    = var.jenkins.password

    oidc                        = {
        host            = module.keycloak.host
        token_url       = "${module.keycloak.url}/auth/realms/${module.realm.name}/protocol/openid-connect/token"
        auth_url        = "${module.keycloak.url}/auth/realms/${module.realm.name}/protocol/openid-connect/auth"
        well_known_url  = "${module.keycloak.url}/auth/realms/${module.realm.name}/.well-known/openid-configuration"
        client_id       = module.jenkins_client.client_id
        client_secret   = module.jenkins_client.client_secret
    }


    deploymanager_url           = module.deploymanager.service_url

    git_ssh                     = {
        host        = "${var.gitlab.host_prefix}.${var.domain}"
        service     = "gitlab"
    }

    binaries                    = {
        maven = {
            url      = module.nexus.url
            username = module.nexus.username
            password = module.nexus.password
        }
        pypi = {
            url      = module.nexus.url
            username = module.nexus.username
            password = module.nexus.password
        }
        registry = {
            host     = module.harbor.host
            username = module.harbor.username
            password = module.harbor.password
        }
    }

}
output "jenkins" {
    value = module.jenkins
}

/********************
    FIRST USER
***********************/

module "gitlab_user_init_api_token" {
    source        = "./gitlab/generate_api_token"
    gitlab_host   = module.gitlab.host
    keycloak_host = module.keycloak.host
    username      = module.realm.first_user.username
    password      = module.realm.first_user.password
    release       = module.gitlab.name
    namespace     = module.gitlab.namespace
    kube_config   = var.kube_config
}

module "jenkins_user_init_api_token" {
    source        = "./jenkins/generate_api_token"
    jenkins_host  = module.jenkins.host
    keycloak_host = module.keycloak.host
    username      = module.realm.first_user.username
    password      = module.realm.first_user.password
    release       = module.jenkins.name
    namespace     = module.jenkins.namespace
    kube_config   = var.kube_config
}

module "user_sync" {
    source      = "./user"
    realm_id    = module.realm.id
    namespace   = var.namespace
    firstname   = "user-sync"
    lastname    = "user-sync"
    email       = "user-sync@${var.domain}"
    username    = "user-sync"
    password    = "dzdbd789"
    jenkins     = module.jenkins
    gitlab      = module.gitlab
    keycloak    = {
        host            = module.keycloak.host
        url             = module.keycloak.url
        client_id       = var.keycloak.client_id
        username        = var.keycloak.username
        password        = var.keycloak.password
    }
    kube_config = var.kube_config
}

output "user_sync" {
    value = module.user_sync
}
/****************************
    KATHRA SERVICES
****************************/
module "kathra_client" {
    source                      = "./keycloak/client"
    
    realm                       = module.realm.name
    client_id                   = "kathra"
    redirect_uri                = "https://dashboard.${var.domain}/*"
    service_accounts_enabled    = true


    keycloak_client_id          = var.keycloak.client_id
    keycloak_username           = var.keycloak.username
    keycloak_password           = var.keycloak.password
    keycloak_url                = module.keycloak.url
}

output "kathra" {
    value = module.kathra_client
}



