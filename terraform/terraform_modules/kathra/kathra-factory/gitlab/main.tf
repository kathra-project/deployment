variable "ingress_host" {
}
variable "ingress_class" {
}
variable "ingress_cert_manager_issuer" {
}
variable "ingress_tls_secret_name" {
  default = {
    unicorn = "gitlab-unicorn-tls"
    registry = "gitlab-registry-tls"
    minio = "gitlab-minio-tls"
  }
}

variable "namespace" { 
}
variable "password" {
}
variable "oidc_url" {
}
variable "oidc_client_id" {
}
variable "oidc_client_secret" {
}
variable "resource_cpu_limit_per_pod" {
    default = "3"
}
variable "resource_memory_limit_per_pod" {
    default = "4Gi"
}
variable "min_replicas" {
    default = "1"
}
variable "max_replicas" {
    default = "1"
}


data "helm_repository" "gitlab" {
  name = "gitlab"
  url  = "https://charts.gitlab.io/"
}

resource "kubernetes_secret" "gitlab-root-pwd" {
  metadata {
    name        = "gitlab-root-pwd"
    namespace   = var.namespace
  }
  data = {
    password    = var.password
  }
}



resource "helm_release" "gitlab" {
  name       = "gitlab"
  repository = data.helm_repository.gitlab.metadata[0].name
  chart      = "gitlab"
  version    = "3.3.5"
  namespace  = var.namespace
  timeout    = 1200
  values = [<<EOF
nginx-ingress:
  enabled: false
certmanager:
  install: false
prometheus:
  install: false

redis:
  resources:

gitlab:
  sidekiq:
    minReplicas: 6
  webservice:
    minReplicas: 6
  unicorn:
    minReplicas: 6
    ingress:
      tls:
        secretName: ${var.ingress_tls_secret_name.unicorn == null ? "gitlab-unicorn-cert" : var.ingress_tls_secret_name.unicorn}
registry:
  hpa:
    minReplicas: 1
    maxReplicas: 2
  ingress:
    tls:
      secretName: ${var.ingress_tls_secret_name.registry == null ? "gitlab-registry-cert" : var.ingress_tls_secret_name.registry}
minio:
  ingress:
    tls:
      secretName: ${var.ingress_tls_secret_name.minio == null ? "gitlab-minio-cert" : var.ingress_tls_secret_name.minio}

global:
  hosts:
    domain: ${var.ingress_host}
    gitlab:
      name: ${var.ingress_host}
    registry:
      name: registry-${var.ingress_host}
    minio:
      name: minio-${var.ingress_host}
  edition: ce
  ingress:
    configureCertmanager: false
    annotations:
      kubernetes.io/ingress.class: "${var.ingress_class}"
      cert-manager.io/issuer: "${var.ingress_cert_manager_issuer}"
    enabled: true

       
  appConfig:
    omniauth:
      enabled: true
      allowSingleSignOn: 
        - saml
        - openid_connect
      blockAutoCreatedUsers: false
      providers:
        - secret: "${kubernetes_secret.gitlab_omniauth_keycloak.metadata[0].name}"
EOF
]

}
resource "kubernetes_secret" "gitlab_omniauth_keycloak" {
  metadata {
    name        = "gitlab-omniauth-keycloak"
    namespace   = var.namespace
  }
  data = {
    "provider" = <<EOF
name: "openid_connect"
label: "keycloak"
args:
  name: "openid_connect"
  scope: ["openid", "profile"]
  response_type: "code"
  issuer: "${var.oidc_url}"
  discovery: true
  client_auth_method: "query"
  uid_field: "uid_field"
  client_options:
    identifier: "${var.oidc_client_id}"
    secret: "${var.oidc_client_secret}"
    redirect_uri: "https://${var.ingress_host}/users/auth/openid_connect/callback"
EOF
  }
}

resource "kubernetes_service" "gitlab_ssh_node_port" {
  metadata {
    name = "gitlab-ssh"
    namespace  = var.namespace
  }
  spec {
    selector = {
      app     = "gitlab-shell"
      release = "gitlab"
    }
    port {
      port        = 22
      target_port = 2222
      node_port    = 30022
    }
    type = "NodePort"
  }
}

output "namespace" {
    value = helm_release.gitlab.namespace
}
output "name" {
    value = helm_release.gitlab.name
}
output "username" {
    value = "admin"
}
output "password" {
    //value = yamldecode(helm_release.gitlab.metadata[0].values).global.initialRootPassword
    value = ""
}
output "host" {
    value = yamldecode(helm_release.gitlab.metadata[0].values).global.hosts.domain
}
output "service" {
    value = "gitlab"
}
output "node_port" {
    value = kubernetes_service.gitlab_ssh_node_port.spec[0].port[0].node_port
}
output "url" {
    value = "https://${yamldecode(helm_release.gitlab.metadata[0].values).global.hosts.domain}"
}