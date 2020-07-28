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

variable "kathra_user_admin" {
    default = {
        username    = "user-sync"
        password    = "dzdbd789"
    }
}
variable "kathra_group_admin" {
    default = "kathra-admin"
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
variable "deploymanager" {
    default = {
        tag           = "stable"
    }
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

    oidc_url                    = module.realm.url
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

    oidc_url                    = module.realm.url
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

    password                    = var.sonarqube.password
    
    oidc_url                    = module.realm.url
    oidc_client_id              = module.sonarqube_client.client_id
    oidc_client_secret          = module.sonarqube_client.client_secret
}
output "sonarqube" {
    value = module.sonarqube
}

/****************************
    DEPLOYMANAGER
****************************/
module "deploymanager" {
    source                      = "./kathra-deploymanager"
    namespace                   = var.namespace

    tag                         = var.deploymanager.tag
    ingress_base                = var.domain
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
        token_url       = module.realm.token_url
        auth_url        = module.realm.auth_url
        well_known_url  = module.keycloak.url
        client_id       = module.jenkins_client.client_id
        client_secret   = module.jenkins_client.client_secret
        group_admin     = var.kathra_group_admin
        user_admin      = var.kathra_user_admin.username
    }
    
    

    deploymanager_url           = module.deploymanager.service_url

    git_ssh                     = {
        host        = "${var.gitlab.host_prefix}.${var.domain}"
        service     = "gitlab-gitlab-shell"
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

    sonar                       = {
        url         = module.sonarqube.url
        username    = module.sonarqube.admin.username
        password    = module.sonarqube.admin.password
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





/********************
    KATHRA SERVICE ACCOUNT
***********************/
module "user_sync" {
    source      = "./user"
    realm_id    = module.realm.id
    namespace   = var.namespace
    firstname   = var.kathra_user_admin.username
    lastname    = var.kathra_user_admin.username
    email       = "${var.kathra_user_admin.username}@${var.domain}"
    username    = var.kathra_user_admin.username
    password    = var.kathra_user_admin.password
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

output "kathra_service_account" {
    value = module.user_sync
}



/********************
    KATHRA GROUP
***********************/
module "group_admin" {
    source      = "./group"
    realm_id    = module.realm.id
    name        = var.kathra_group_admin
    members     = [ module.user_sync.username ]
    keycloak    = {
        host            = module.keycloak.host
        url             = module.keycloak.url
        client_id       = var.keycloak.client_id
        username        = var.keycloak.username
        password        = var.keycloak.password
    }
}



/****************************
    KATHRA SERVICES
****************************/
module "kathra_client" {
    source                      = "./keycloak/client_with_resource_management"
    
    realm                       = module.realm.name
    client_id                   = "kathra"
    redirect_uri                = "https://dashboard.${var.domain}/*"
    web_origins                 = [ "https://dashboard.${var.domain}" ]

    keycloak_client_id          = var.keycloak.client_id
    keycloak_username           = var.keycloak.username
    keycloak_password           = var.keycloak.password
    keycloak_url                = module.keycloak.url
}

output "kathra" {
    value = module.kathra_client
}



