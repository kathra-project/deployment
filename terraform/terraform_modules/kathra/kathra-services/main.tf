variable "namespace" { 
}

variable "kathra" {
  default = {
        images = {
          registry_url    = "registry.hub.docker.com"
          root_repository = "kathra"
          docker_conf     = ""
          tag             = "stable"
        }
        domain   = "kathra.org"
        ingress  = {
          appmanager = {
            host              = "appmanager.kathra.org"
            class             = ""
            tls_secret_name   = "appmanager-cert"
          }
          dashboard = {
            host              = "dashboard.kathra.org"
            class             = ""
            tls_secret_name   = "dashboard-cert"
          }
          platformmanager = {
            host              = "platformmanager.kathra.org"
            class             = ""
            tls_secret_name   = "platformmanager"
          }
        }
        arangodb = {
          password  = null
        }
        oidc     = {
          client_id     = "kathra-resource-manager"
          client_secret = ""
          auth_url      = "https://keycloak.kathra.org/auth"
        }
    }
}

variable "gitlab" {
    default = {
      url           = null
      username      = null
      password      = null
      token         = null
      root_project  = "kathra-projects"
    }
}

variable "harbor" {
    default = {
      url           = null
      username      = null
      password      = null
    }
}

variable "jenkins" {
    default = {
      url           = null
      username      = null
      token         = null
    }
}

variable "keycloak" {
}


variable "nexus" {
    default = {
      url           = null
      username      = null
      password      = null
    }
}


resource "helm_release" "kathra" {
  name       = "kathra"
  chart      = "${path.module}/../../../../kathra-services"
  namespace  = var.namespace
  timeout    = 600
  values     = [<<EOF

global:
  domain: "${var.kathra.domain}"
  docker:
    registry: 
      url: "${var.kathra.images.registry_url}"
      root_repository: "${var.kathra.images.root_repository}"
      secret: "${var.kathra.images.docker_conf}"
  keycloak:
    auth_url: "${var.keycloak.user.auth_url}"
    realm: "${var.keycloak.user.realm}"
    kathra_services_client:
      id: "${var.kathra.oidc.client_id}"
      secret: "${var.kathra.oidc.client_secret}"

kathra-appmanager:
  image: appmanager
  version: "${var.kathra.images.tag}"
  tls: true
  delete_zip_file: "true"
  services_url:
    codegen_helm: codegen-helm/api/v1
    codegen_swagger: codegen-swagger/api/v1
    binaryrepository_harbor: binaryrepositorymanager-harbor/api/v1
    source_manager: sourcemanager/api/v1
    pipeline_manager: pipelinemanager/api/v1
    resource_manager: resourcemanager/api/v1
    catalogmanager: catalogmanager/api/v1
    pipeline_webhook: https://${var.kathra.ingress.appmanager.host}/api/v1/webhook
  resources:
    limits:
      cpu: 900m
      memory: 1Gi
    requests:
      cpu: 50m
      memory: 128Mi
  ingress:
    annotations:
      kubernetes.io/ingress.class: "${var.kathra.ingress.class}"
      cert-manager.io/issuer: "${var.kathra.ingress.cert-manager_issuer}"
      ingress.kubernetes.io/force-ssl-redirect: "true"
    tls:
    - hosts:
      - "${var.kathra.ingress.appmanager.host}"
      secretName: "${var.kathra.ingress.appmanager.tls_secret_name}"

kathra-binaryrepositorymanager-harbor:
  image: binaryrepositorymanager-harbor
  version: "${var.kathra.images.tag}"
  services_url:
    resource_manager: resourcemanager/api/v1
  harbor:
    url: "${var.harbor.url}"
    username: "${var.harbor.username}"
    password: "${var.harbor.password}"
  keycloak:
    username: "${var.keycloak.user.username}"
    password: "${var.keycloak.user.password}"
  resources:
    limits:
      cpu: 500m
      memory: 768Mi
    requests:
      cpu: 50m
      memory: 128Mi
  ingress:
    annotations:
      kubernetes.io/ingress.class: "${var.kathra.ingress.class}"
      cert-manager.io/issuer: "${var.kathra.ingress.cert-manager_issuer}"
      ingress.kubernetes.io/force-ssl-redirect: "true"
    tls:
    - hosts:
      - binaryrepositorymanager-harbor.${var.kathra.domain}
      secretName: binaryrepositorymanager-harbor-cert


kathra-catalogmanager:
  image: catalogmanager-helm
  version: "${var.kathra.images.tag}"
  tls: true
  services_url:
    resource_manager: http://resourcemanager/api/v1
  helm:
    repoName: kathra
    url: "${var.harbor.url}/chartrepo"
    login: "${var.harbor.username}"
    password: "${var.harbor.password}"
  keycloak:
    username: "${var.keycloak.user.username}"
    password: "${var.keycloak.user.password}"
  resources:
    limits:
      cpu: 500m
      memory: 768Mi
    requests:
      cpu: 50m
      memory: 128Mi
  ingress:
    annotations:
      kubernetes.io/ingress.class: "${var.kathra.ingress.class}"
      cert-manager.io/issuer: "${var.kathra.ingress.cert-manager_issuer}"
      ingress.kubernetes.io/force-ssl-redirect: "true"
    tls:
    - hosts:
      - catalogmanager.${var.kathra.domain}
      secretName: catalogmanager-cert

kathra-codegen-swagger:
  image: codegen-swagger
  version: "${var.kathra.images.tag}"
  tls: true
  repository:
    url: "${var.nexus.url}"
    pythonRepo: pip-all/simple
  resources:
    limits:
      cpu: 500m
      memory: 768Mi
    requests:
      cpu: 50m
      memory: 128Mi
  ingress:
    annotations:
      kubernetes.io/ingress.class: "${var.kathra.ingress.class}"
      cert-manager.io/issuer: "${var.kathra.ingress.cert-manager_issuer}"
      ingress.kubernetes.io/force-ssl-redirect: "true"
    tls:
    - hosts:
      - codegen-swagger.${var.kathra.domain}
      secretName: codegen-swagger-cert


kathra-codegen-helm:
  image: codegen-helm
  version: "${var.kathra.images.tag}"
  tls: true
  resources:
    limits:
      cpu: 300m
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi
  ingress:
    annotations:
      kubernetes.io/ingress.class: "${var.kathra.ingress.class}"
      cert-manager.io/issuer: "${var.kathra.ingress.cert-manager_issuer}"
      ingress.kubernetes.io/force-ssl-redirect: "true"
    tls:
    - hosts:
      - codegen-helm.${var.kathra.domain}
      secretName: codegen-helm-cert


kathra-dashboard: 
  image: dashboard
  version: "${var.kathra.images.tag}"
  tls: true
  services_url:
    platform_manager: "wss://${var.kathra.ingress.platformmanager.host}/spm"
    app_manager: "https://${var.kathra.ingress.appmanager.host}/api/v1"
    jenkins_url: "${var.jenkins.url}"
    base_domain: "${var.kathra.domain}"
  resources:
    limits:
      cpu: 300m
      memory: 256Mi
    requests:
      cpu: 50m
      memory: 64Mi
  ingress:
    annotations:
      kubernetes.io/ingress.class: "${var.kathra.ingress.class}"
      cert-manager.io/issuer: "${var.kathra.ingress.cert-manager_issuer}"
      ingress.kubernetes.io/force-ssl-redirect: "true"
    tls:
    - hosts:
      - ${var.kathra.ingress.dashboard.host}
      secretName: ${var.kathra.ingress.dashboard.tls_secret_name}

kathra-pipelinemanager:
  image: pipelinemanager-jenkins
  version: "${var.kathra.images.tag}"
  tls: true
  jenkins:
    url: "${var.jenkins.url}"
    username: "${var.jenkins.username}"
    api_token: "${var.jenkins.token}"
  resources:
    limits:
      cpu: 500m
      memory: 768Mi
    requests:
      cpu: 50m
      memory: 128Mi
  ingress:
    annotations:
      kubernetes.io/ingress.class: "${var.kathra.ingress.class}"
      cert-manager.io/issuer: "${var.kathra.ingress.cert-manager_issuer}"
      ingress.kubernetes.io/force-ssl-redirect: "true"
    tls:
    - hosts:
      - pipelinemanager.${var.kathra.domain}
      secretName: pipelinemanager-cert

kathra-platformmanager:
  image: platformmanager-kube
  version: "${var.kathra.images.tag}"
  tls: true
  websocket:
    port: "8080"
  catalog_manager:
    url: http://catalogmanager/api/v1
  deployment:
    ingress_controller: "${var.kathra.ingress.class}"
    tld: "${var.kathra.domain}"
  resources:
    limits:
      cpu: 500m
      memory: 768Mi
    requests:
      cpu: 50m
      memory: 128Mi
  ingress:
    annotations:
      kubernetes.io/ingress.class: "${var.kathra.ingress.class}"
      cert-manager.io/issuer: "${var.kathra.ingress.cert-manager_issuer}"
      ingress.kubernetes.io/force-ssl-redirect: "true"
    tls:
    - hosts:
      - "${var.kathra.ingress.platformmanager.host}"
      secretName: "${var.kathra.ingress.platformmanager.tls_secret_name}"

kathra-resourcemanager:
  image: resourcemanager-arangodb
  version: "${var.kathra.images.tag}"
  tls: true
  arango:
    host: resource-db
    port: "8529"
    database: KATHRA
    user: root
    password: "${var.kathra.arangodb.password}"
  resources:
    limits:
      cpu: 1
      memory: 2Gi
    requests:
      cpu: 50m
      memory: 128Mi
  ingress:
    annotations:
      kubernetes.io/ingress.class: "${var.kathra.ingress.class}"
      cert-manager.io/issuer: "${var.kathra.ingress.cert-manager_issuer}"
      ingress.kubernetes.io/force-ssl-redirect: "true"
    tls:
    - hosts:
      - resourcemanager.${var.kathra.domain}
      secretName: resourcemanager-cert

db:
  db:
    password: "${var.kathra.arangodb.password}"

kathra-sourcemanager:
  image: sourcemanager-gitlab
  version: "${var.kathra.images.tag}"
  tls: true
  temp_repos_folder: /tmp/kathra-sourcemanager-git-repos
  dir_creation_max_retry: "3"
  delete_temp_folder: "true"
  delete_temp_zip: "true"
  gitlab:
    url: "${var.gitlab.url}"
    api_token: "${var.gitlab.token}"
    parent_group: "${var.gitlab.root_project}"
  user_manager:
    url: usermanager
  resources:
    limits:
      cpu: 500m
      memory: 768Mi
    requests:
      cpu: 50m
      memory: 256Mi
  ingress:
    annotations:
      kubernetes.io/ingress.class: "${var.kathra.ingress.class}"
      cert-manager.io/issuer: "${var.kathra.ingress.cert-manager_issuer}"
      ingress.kubernetes.io/force-ssl-redirect: "true"
    tls:
    - hosts:
      - sourcemanager.${var.kathra.domain}
      secretName: sourcemanager-cert

kathra-usermanager:
  image: usermanager-keycloak
  version: "${var.kathra.images.tag}"
  tls: true
  resources:
    limits:
      cpu: 300m
      memory: 768Mi
    requests:
      cpu: 50m
      memory: 256Mi
  keycloak:
    adminRealm: "${var.keycloak.admin.realm}"
    adminClientId: "${var.keycloak.admin.client_id}"
    adminUsername: "${var.keycloak.admin.username}"
    adminPassword: "${var.keycloak.admin.password}"
  ingress:
    annotations:
      kubernetes.io/ingress.class: "${var.kathra.ingress.class}"
      cert-manager.io/issuer: "${var.kathra.ingress.cert-manager_issuer}"
      ingress.kubernetes.io/force-ssl-redirect: "true"
    tls:
    - hosts:
      - usermanager.${var.kathra.domain}
      secretName: usermanager-cert

kathra-sync:
  keycloak:
    login: "${var.keycloak.user.username}"
    password: "${var.keycloak.user.password}"
  image: users-sync
  version: "${var.kathra.images.tag}"
  resources:
    limits:
      cpu: 300m
      memory: 768Mi
    requests:
      cpu: 50m
      memory: 256Mi
    
EOF
]

}

output "namespace" {
    value = helm_release.kathra.namespace
}
output "name" {
    value = helm_release.kathra.name
}