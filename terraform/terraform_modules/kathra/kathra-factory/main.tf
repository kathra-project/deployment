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
variable "storage_class" {
    default = "default"
}
variable "kube_config" {

}

variable "kathra_user_admin" {
    default = {
        username    = "user-sync"
    }
}
variable "kathra_group_admin" {
    default = "kathra-admin"
}

variable "keycloak" {
    default = {
        host_prefix   = "keycloak"
        username      = null
        password      = null
        client_id     = "admin-cli"
        groups        = {
            "my-team-a" : {
                name = "my-team-a"
            }
        }
        users         = {
            "user_a" = {
                firstname   = "Firstname UserA"
                lastname    = "Firstname UserA"
                email       = "user_a@kathra.org"
                password_initial    = "123"
                memberOf    = [
                    "my-team"
                ]
            }
        }
    }
}
variable "jenkins" {
    default = {
        host_prefix   = "jenkins"
    }
}
variable "nexus" {
    default = {
        host_prefix   = "nexus"
    }
}
variable "harbor" {
    default = {
        host_prefix   = "harbor"
    }
}
variable "gitlab" {
    default = {
        host_prefix   = "gitlab"
    }
}
variable "sonarqube" {
    default = {
        host_prefix   = "sonarqube"
    }
}
variable "deploymanager" {
    default = {
        tag           = "stable"
    }
}

variable "identities" {
    default = {
        "users" = {
            "userA" = {
                firstname           = "Firstname UserA"
                lastname            = "Firstname UserA"
                email               = "user_a@kathra.org"
                initialPassword    = "123"
            }
        }
        "groups" = {
            "teamA" = {
                name      = "team-a"
                members   = ["user_a"]
            }
        }
    }
}

variable "groups" {
    default = {
    "team-a" = {
        name   = "team-a"
    }}
}

variable "groups_memberships" {
    default = {
    "team-a" = {
        members   = ["user_a"]
    }}
}

/*****************************
Password generation for real (admin_password) and technical admin (kathra_user_admin)
******************************/
resource "random_password" "admin_password" {
    length = 20
    special = false
}
resource "random_password" "kathra_user_admin" {
    length = 20
    special = false
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
    
    storage_class               = var.storage_class
}
output "keycloak" {
    value = module.keycloak
}


provider "keycloak" {
    client_id     = var.keycloak.client_id
    username      = var.keycloak.username
    password      = var.keycloak.password
    url           = module.keycloak.url
    initial_login = false
}

module "realm" {
    source                  = "./keycloak/realm"
    keycloak_realm          = "kathra"
    #first_group_name        = "my-team"
    #first_user_login        = "user"
    #first_user_password     = "123"
    keycloak_url            = module.keycloak.url
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
    password                    = var.keycloak.password

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
    password                    = var.keycloak.password
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
    keycloak_url            = module.keycloak.url
}
module "sonarqube" {
    source                      = "./sonarqube"

    ingress_host                = "${var.sonarqube.host_prefix}.${var.domain}"
    ingress_class               = var.ingress_class
    ingress_cert_manager_issuer = var.ingress_cert_manager_issuer
    ingress_tls_secret_name     = var.ingress_tls_secret_name

    namespace                   = var.namespace

    password                    = var.keycloak.password
    
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
        username = module.harbor.admin.username
        password = module.harbor.admin.password
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
    keycloak_url            = module.keycloak.url
}

module "jenkins" {
    source                      = "./jenkins"

    ingress_host                = "${var.jenkins.host_prefix}.${var.domain}"
    ingress_class               = var.ingress_class
    ingress_cert_manager_issuer = var.ingress_cert_manager_issuer
    ingress_tls_secret_name     = var.ingress_tls_secret_name

    storage_class               = var.storage_class

    namespace                   = var.namespace
    password                    = var.keycloak.password

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
            username = module.nexus.admin.username
            password = module.nexus.admin.password
        }
        pypi = {
            url      = module.nexus.url
            username = module.nexus.admin.username
            password = module.nexus.admin.password
        }
        registry = {
            host     = module.harbor.host
            username = module.harbor.admin.username
            password = module.harbor.admin.password
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
    password    = random_password.kathra_user_admin.result
    jenkins     = module.jenkins
    gitlab      = module.gitlab
    keycloak    = {
        host    = module.keycloak.host
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
    keycloak_url                = module.keycloak.url
}

output "kathra" {
    value = module.kathra_client
}




/****************************
    KATHRA USERS
****************************/
resource "keycloak_user" "user" {
    for_each    = var.identities.users

    realm_id    = module.realm.id
    username    = lower(each.key)
    enabled     = true
    email       = each.value.email
    first_name  = each.value.firstname
    last_name   = each.value.lastname
    initial_password {
      value     = each.value.initialPassword
      temporary = true
    }
}

resource "keycloak_group" "group" {
    for_each    = var.identities.groups
     
    realm_id    = module.realm.id
    name        = lower(each.value.name)
    parent_id   = module.realm.root_group.id
}

resource "keycloak_group_memberships" "members" {
    for_each = var.identities.groups

    realm_id = module.realm.id
    group_id = keycloak_group.group[each.key].id
    members  = each.value.members
}

output "identities" {
    value = {
        "users"             = keycloak_user.user
        "group"             = keycloak_group.group
        "group_memberships" = keycloak_group_memberships.members
    }
}